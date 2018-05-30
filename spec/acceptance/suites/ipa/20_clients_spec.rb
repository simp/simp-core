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
          include 'simp::ipa::install'
        }
        # The puppetserver
        node /puppet/ {
          include 'simp_options'
          include 'simp'
          include 'simp::server'
          include 'pupmod'
          include 'pupmod::master'
          include 'simp::ipa::install'
        }
      EOF
      create_remote_file(master, '/etc/puppetlabs/code/environments/production/manifests/site.pp', site_pp)

      hiera = YAML.load(on(master, 'cat /etc/puppetlabs/code/environments/production/hieradata/default.yaml').stdout)
      default_yaml = hiera.merge(
        'simp::ipa::install::ensure'   => 'present',
        'simp::ipa::install::password' => enroll_pass,
        'simp::ipa::install::server'   => [ipa_fqdn],
        'simp::ipa::install::domain'   => ipa_domain,
        # 'simp::ipa::install::install_options' => {
        #   'verbose' => nil,
        # }
      ).to_yaml
      create_remote_file(master, '/etc/puppetlabs/code/environments/production/hieradata/default.yaml', default_yaml)
    end
  end

  context 'add hosts to ipa server' do
    block_on(ipa_clients) do |client|
      it "should run host-add for #{client}" do
        client_ip = fact_on(client,'ipaddress_eth1')
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

  context 'client prep' do
    ipa_clients.each do |client|
      next if skip_fips(client)

      it 'should make sure the hostname is fully qualified' do
        fqdn = "#{client}.#{domain}"
        # Ensure that the hostname is set to the FQDN
        on(client, "hostname #{fqdn}")
        create_remote_file(client, '/etc/hostname', fqdn)
        create_remote_file(client, '/etc/sysconfig/network', <<-EOF.gsub(/^\s+/,'')
            NETWORKING=yes
            HOSTNAME=#{fqdn}
            PEERDNS=no
          EOF
        )
        client.reboot
        retry_on(client, 'uptime', :retry_interval => 5 )
      end
    end

    context 'run puppet' do
      it 'set up and run puppet' do
        block_on(agents, :run_in_parallel => true) do |agent|
          retry_on(agent, 'puppet agent -t',
            :desired_exit_codes => [0],
            :retry_interval     => 15,
            :max_retries        => 4,
            :verbose            => true
          )
        end
      end
    end
  end
end
