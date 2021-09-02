require 'spec_helper_integration'

test_name 'puppetlast'

# facts gathered here are executed when the file first loads and
# use the facter gem temporarily installed into system ruby
puppetserver      = only_host_with_role(hosts, 'master')
agents            = hosts_with_role(hosts, 'agent')

describe 'puppetlast checks' do

  let(:agent_fqdns) do
    agents.map do |host|
      fact_on(host, 'fqdn')
    end
  end

  it 'should obtain the last checkin time of the hosts' do
    output = on(puppetserver, '/usr/local/sbin/puppetlast -E production').stdout.strip

    agent_fqdns.each do |agent_fqdn|
      expect(output).to match(/^#{agent_fqdn} checked in \d+(\.\d+)? minutes ago$/)
    end
  end
end
