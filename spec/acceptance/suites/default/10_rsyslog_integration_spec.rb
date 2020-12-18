require 'spec_helper_integration'

test_name 'rsyslog integration'

# The rsyslog and simp_rsyslog module acceptance tests verify the plumbing
# of rsyslog connectivity.  See the shared example for more details.

syslog_servers = hosts_with_role(hosts, 'syslog_server')
non_syslog_servers = hosts - syslog_servers
master      = only_host_with_role(hosts, 'master')
# facts gathered here are executed when the file first loads and
# use the factor gem temporarily installed into system ruby
domain = fact_on(master, 'domain')

describe 'Validation of rsyslog forwarding' do
  options = {
    :domain      => domain,
    :scenario    => 'simp',
    :master      => master
  }

  include_examples 'SIMP Rsyslog Tests', syslog_servers, non_syslog_servers, options
end

