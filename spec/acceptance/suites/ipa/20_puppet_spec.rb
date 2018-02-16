require 'spec_helper_integration'

describe 'ip and puppet together finally' do
  agents = hosts_with_role(hosts, 'agent')

  # make puppet run on itself first
  ordered_agents = agents.select{|h|h=='puppet'} | agents

  ordered_agents.each do |agent|
    context 'agents' do
      it "should run the agent on #{agent}" do
        # require 'pry';binding.pry if fact_on(agent, 'hostname') == 'agent'
        on(agent, 'puppet agent -t --server puppet --show_diff', accept_all_exit_codes: true)
        Simp::TestHelpers.wait(30)
        on(agent, 'puppet agent -t --server puppet --show_diff', accept_all_exit_codes: true)
        agent.reboot
        Simp::TestHelpers.wait(240)
        on(agent, 'puppet agent -t --server puppet --show_diff', acceptable_exit_codes: [0,2])
      end
      it 'should be idempotent' do
        Simp::TestHelpers.wait(30)
        on(agent, 'puppet agent -t --server puppet --show_diff', acceptable_exit_codes: [0])
      end
    end
  end
end
