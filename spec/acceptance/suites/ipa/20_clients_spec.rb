require 'spec_helper_integration'

def skip_fips(host)
  if fips_enabled(host) && host.host_hash[:roles].include?('no_fips')
    return true
  else
    return false
  end
end

def run_ipa_cmd(host, pass, cmd)
  on(host, "echo \"#{pass}\" | kinit admin")
  result = on(host, cmd)
  on(host, 'kdestroy')

  result
end

describe 'sets up IPA clients' do

  ipa_server  = hosts_with_role(hosts, 'ipa_server').first
  ipa_clients = hosts_with_role(hosts, 'ipa_client')
  domain      = fact_on(master, 'domain')

  admin_password = '@dm1n=P@ssw0r'
  enroll_pass    = 'en0llm3ntp@ssWor^'
  ipa_domain     = domain
  ipa_fqdn       = fact_on(ipa_server, 'fqdn')

  context 'classify nodes' do
    it 'modify the existing hieradata' do
      site_pp = <<-EOF
        # All nodes
        node default {
          include 'simp_options'
          include 'simp'
          include 'simp_ipa::client::install'
        }
        # The puppetserver
        node /puppet/ {
          include 'simp_options'
          include 'simp'
          include 'simp::server'
          include 'pupmod'
          include 'pupmod::master'
          include 'simp_ipa::client::install'
        }
      EOF
      create_remote_file(master, '/etc/puppetlabs/code/environments/production/manifests/site.pp', site_pp)

      hiera = YAML.load(on(master, 'cat /etc/puppetlabs/code/environments/production/data/default.yaml').stdout)
      default_yaml = hiera.merge(
        'simp_ipa::client::install::ensure'   => 'present',
        'simp_ipa::client::install::password' => enroll_pass,
        'simp_ipa::client::install::server'   => [ipa_fqdn],
        'simp_ipa::client::install::domain'   => ipa_domain,
        'simp_ipa::client::install::hostname' => '%{trusted.certname}',
        # 'simp_ipa::client::install::install_options' => {
        #   'verbose' => nil,
        # }
      ).to_yaml
      create_remote_file(master, '/etc/puppetlabs/code/environments/production/data/default.yaml', default_yaml)
    end
  end

  context 'add hosts to ipa server' do
    block_on(ipa_clients) do |client|
      it "should run host-add for #{client}" do
        client_ip = client.reachable_name
        expect(client_ip).to_not be_nil

        cmd = [
          'ipa -v host-add',
          "#{client}.#{ipa_domain}",
          "--ip-address=#{client_ip}",
          '--no-reverse',
          "--password=#{enroll_pass}"
        ].join(' ')

        run_ipa_cmd(ipa_server, admin_password, cmd)
      end
    end
  end

  context 'run puppet' do
    it 'set up and run puppet' do
      block_on(agents, :run_in_parallel => false) do |agent|
        retry_on(agent, 'puppet agent -t',
          :desired_exit_codes => [0],
          :retry_interval     => 15,
          :max_retries        => 4,
          :verbose            => true.to_s # work around beaker bug
        )
      end
    end
  end
end
