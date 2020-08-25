require 'spec_helper_integration'

test_name 'disabling FIPS after fully configured with FIPS enabled'

master      = only_host_with_role(hosts, 'master')
master_fqdn = fact_on(master, 'fqdn')
agents      = hosts_with_role(hosts, 'agent')

describe 'disabling FIPS after fully configured with FIPS enabled' do

  context 'set up hiera to disable FIPS' do
    let(:prod_env_dir) { '/etc/puppetlabs/code/environments/production' }
    let(:prod_env_default_yaml) { File.join(prod_env_dir, 'data', 'default.yaml') }

    it 'should disable compliance enforcement and disable FIPS' do
      hiera = YAML.load(on(master, "cat #{prod_env_default_yaml}").stdout)

      # Set profile list to empty string in the existing hiera, because
      # when no profiles are specified, there is nothing to enforce!
      hiera['compliance_markup::enforcement'] = []

      # disable FIPS
      hiera['simp_options::fips'] = false

      create_remote_file(master, "#{prod_env_default_yaml}", hiera.to_yaml)
      on(master, "cat #{prod_env_default_yaml}")
    end
  end

  context 'apply FIPS-disabling changes' do
    let(:puppetserver_status_cmd) { puppetserver_status_command(master_fqdn) }

    # can't apply most FIPS-related changes until after reboot, but can undo
    # all the compliance-enforcement settings
    it 'should undo compliance-enforced settings on agents' do
      block_on(agents, :run_in_parallel => false) do |agent|
        # FIXME: By the time we get to the last node, the ssh connection may have been
        # aggressively terminated by beaker for that node instead of being handled with
        # reconnect-after-timeout logic.
        ensure_ssh_connection(agent)

        retry_on(agent, 'puppet agent -t',
          :desired_exit_codes => [0,2],
          :retry_interval     => 15,
          :max_retries        => 5,
          :verbose            => true.to_s  # work around beaker bug
        )
      end
    end

    it 'should reboot the agents to apply boot time config' do
      block_on(agents, :run_in_parallel => false) do |agent|
        agent.reboot
      end
    end

    it 'FIPS should be disabled on each agent' do
      block_on(agents, :run_in_parallel => false) do |agent|
        expect( fips_enabled(agent) ).to be false
      end
    end

    it 'should apply non-FIPS-mode settings on agents' do
      # Wait for the puppetserver to be ready to receive requests
      retry_on(master, puppetserver_status_cmd, :retry_interval => 10)

      block_on(agents, :run_in_parallel => false) do |agent|
        # Wait for the machine to come back up
        retry_on(agent, 'uptime', :retry_interval => 15 )

        retry_on(agent, 'puppet agent -t',
          :desired_exit_codes => [0,2],
          :retry_interval     => 15,
          :max_retries        => 5,
          :verbose            => true.to_s  # work around beaker bug
        )
      end
    end
  end
end
