# require 'spec_helper_integration'

describe 'run puppet on every node' do

  agents = hosts_with_role(hosts, 'agent')

  # make puppet run on itself first
  ordered_agents = agents.select{ |h| h == 'puppet' } | agents

  # ordered_agents.each do |agent|
  #   context 'agents' do
  #     it "should run the agent on #{agent}" do
  #       retry_on(agent, 'puppet agent -t',
  #         :desired_exit_codes => [0],
  #         :retry_interval     => 15,
  #         :max_retries        => 5,
  #         :verbose            => true
  #       )
  #     end
  #   end
  # end
end
