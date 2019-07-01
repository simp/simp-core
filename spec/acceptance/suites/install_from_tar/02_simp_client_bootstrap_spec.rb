require 'spec_helper_integration'

test_name 'Bootstrap SIMP clients'

# facts gathered here are executed when the file first loads and
# use the factor gem temporarily installed into system ruby
master      = only_host_with_role(hosts, 'master')
master_fqdn = fact_on(master, 'fqdn')
agents      = hosts_with_role(hosts, 'agent')
domain      = fact_on(master, 'domain')

describe 'Bootstrap SIMP clients' do
  config = {
    :domain      => domain,
    :master      => master,
    :master_fqdn => master_fqdn
  }

  include_examples 'SIMP client manual bootstrap', agents, config

end
