require 'spec_helper_integration'

describe 'set up IPA clients' do

  ipa_server  = hosts_with_role(hosts, 'ipa_server').first
  ipa_clients = hosts_with_role(hosts, 'ipa_client')
  domain      = fact_on(master, 'domain')

  ipa_domain     = domain
  ipa_fqdn       = fact_on(ipa_server, 'fqdn')

  context 'add host entries to IPA with an enrollment password' do
    block_on(ipa_clients) do |client|
      it "should run host-add with a OTP for #{client}" do
        client_ip = client.reachable_name
        expect(client_ip).to_not be_nil

        cmd = [
          'ipa -v host-add',
          "#{client}.#{ipa_domain}",
          "--ip-address=#{client_ip}",
          '--no-reverse',
          "--password=#{ipa_bulk_enroll_password}"
        ].join(' ')

        run_ipa_cmd(ipa_server, cmd)
        ensure_ssh_connection(client)
      end
    end
  end

  context 'join hosts to the IPA domain using simp_ipa::client::install' do
    let(:default_yaml_filename) {
      '/etc/puppetlabs/code/environments/production/data/default.yaml'
    }

    it 'should configure hiera for simp_ipa::client::install' do
      hiera = YAML.load(on(master, "cat #{default_yaml_filename}").stdout)
      updated_hiera = hiera.merge(
        'simp_ipa::client::install::ensure'   => 'present',
        'simp_ipa::client::install::password' => ipa_bulk_enroll_password,
        'simp_ipa::client::install::server'   => [ipa_fqdn],
        'simp_ipa::client::install::domain'   => ipa_domain,
        'simp_ipa::client::install::hostname' => '%{trusted.certname}',
      )
      updated_hiera['classes'] << 'simp_ipa::client::install'
      default_yaml = updated_hiera.to_yaml
      create_remote_file(master, default_yaml_filename, default_yaml)
      on(master, "cat #{default_yaml_filename}")
    end

    it 'should re-establish connectivity' do
      agents.each do |agent|
        ensure_ssh_connection(agent)
      end
    end

    it 'should apply the configuration' do
      agents.each do |agent|
        retry_on(agent, 'puppet agent -t',
          :desired_exit_codes => [0],
          :retry_interval     => 15,
          :max_retries        => 5,
          :verbose            => true.to_s  # work around beaker bug
        )

        #  try to keep connectivity to other agents
        (agents - [ agent ]).each do |host|
          ensure_ssh_connection(host)
        end
      end
    end
  end
end
