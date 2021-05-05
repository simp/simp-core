require_relative '../helpers'

include Acceptance::Helpers::PuppetHelper
include Acceptance::Helpers::Utils

# Bootstrap manually (i.e., without use of client bootstrap
# scripts used in kickstart)
#
# options keys:
#   :domain      - test domain
#   :master      - puppetserver Host
#   :master_fqdn - FQDN of the puppetmaster
#
shared_examples 'SIMP client manual bootstrap' do |agents, options|

  let(:domain) { options[:domain] }
  let(:master) { options[:master] }
  let(:master_fqdn) { options[:master_fqdn] }
  let(:puppetserver_status_cmd) { puppetserver_status_command(master_fqdn) }

  context 'puppet master' do
    it 'should generate agent application certs using FakeCA' do
      generate_application_certs(master, agents, domain)
    end
  end

  context 'puppet agents' do
    it 'should install packages needed for client bootstrapping' do
      block_on(agents, :run_in_parallel => false) do |agent|
        # TODO This is carryover from an earlier version of the test...
        #      Do we need net-tools?
        agent.install_package('net-tools')
      end
    end

    it 'should set up puppet' do
      block_on(agents, :run_in_parallel => false) do |agent|
        on(agent, "puppet config set server #{master_fqdn}")
        on(agent, 'puppet config set masterport 8140')
        on(agent, 'puppet config set ca_port 8141')
      end
    end

    it 'should run puppet on each client until no more changes are required' do
      agents.each do |agent|
        retry_on(agent, 'puppet agent -t',
          :desired_exit_codes => [0],
          :retry_interval     => 15,
          :max_retries        => 5,
          :verbose            => true.to_s  # work around beaker bug
        )

        # try to keep connectivity to other agents
        (agents - [ agent ]).each do |host|
          ensure_ssh_connection(host)
        end
      end
    end

    it 'should reboot the clients to apply boot time config' do
      agents.each do |agent|
        agent.reboot
      end
    end

    it 'should complete client config with a few puppet runs on each client' do
      block_on(agents, :run_in_parallel => false) do |agent|

        # Wait for the puppetserver to be ready to receive requests
        # and for the machine to come back up
        retry_on(master, puppetserver_status_cmd, :retry_interval => 10)
        retry_on(agent, 'uptime', :retry_interval => 15 )

        # Run puppet until no more changes are required
        retry_on(agent, 'puppet agent -t',
          :desired_exit_codes => [0],
          :retry_interval     => 15,
          :max_retries        => 3,
          :verbose            => true.to_s # work around beaker bug
        )
      end
    end
  end
end
