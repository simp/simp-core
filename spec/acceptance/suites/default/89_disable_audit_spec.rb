require 'spec_helper_integration'

test_name 'disabling auditing to prep for compliance enforcement'

master      = only_host_with_role(hosts, 'master')
master_fqdn = fact_on(master, 'fqdn')
agents      = hosts_with_role(hosts, 'agent')

describe 'disabling auditd to ensure that compliance enforcement works' do

  context 'set up hiera to disable auditing' do
    let(:prod_env_dir) { '/etc/puppetlabs/code/environments/production' }
    let(:prod_env_default_yaml) { File.join(prod_env_dir, 'data', 'default.yaml') }

    it 'should disable compliance enforcement and disable auditd' do
      hiera = YAML.load(on(master, "cat #{prod_env_default_yaml}").stdout)

      # Set profile list to empty string in the existing hiera, because
      # when no profiles are specified, there is nothing to enforce!
      hiera['compliance_markup::enforcement'] = []

      # disable auditd
      hiera['simp_options::auditd'] = true
      hiera['auditd::enable'] = false

      create_remote_file(master, "#{prod_env_default_yaml}", hiera.to_yaml)
      on(master, "cat #{prod_env_default_yaml}")
    end
  end

  context 'apply auditd-disabling changes' do
    let(:puppetserver_status_cmd) { puppetserver_status_command(master_fqdn) }

    # can't apply most auditd-related changes until after reboot, but can undo
    # all the compliance-enforcement settings
    it 'should undo compliance-enforced settings on agents' do
      block_on(agents, :run_in_parallel => false) do |agent|
        # FIXME: By the time we get to the last node, the ssh connection may have been
        # aggressively terminated by beaker for that node instead of being handled with
        # reconnect-after-timeout logic.
        ensure_ssh_connection(agent)

        # We need to do this because the simplib__auditd fact will not be
        # triggered until after the first puppet run which will cause PAM to
        # deny access to the system due to the pam_tty_audit bug.
        retry_on(agent, 'puppet agent -t; puppet agent -t',
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

    it 'auditd should be disabled on each agent' do
      block_on(agents, :run_in_parallel => false) do |agent|
        auditd_status = YAML.safe_load(on(agent, 'puppet resource service auditd --to_yaml').stdout)
        expect(auditd_status['service']['auditd']['ensure']).not_to eq 'running'
      end
    end

    it 'should apply non-auditd-mode settings on agents' do
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
