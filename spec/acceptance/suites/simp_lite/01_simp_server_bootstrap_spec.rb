require 'spec_helper_integration'

test_name 'Configure and bootstrap SIMP puppetserver'

# facts gathered here are executed when the file first loads and
# use the factor gem temporarily installed into system ruby
master              = only_host_with_role(hosts, 'master')
master_fqdn         = fact_on(master, 'fqdn')
syslog_servers      = hosts_with_role(hosts, 'syslog_server')
syslog_server_fqdns = syslog_servers.map { |server| fact_on(server, 'fqdn') }
domain              = fact_on(master, 'domain')

describe 'Configure and bootstrap SIMP puppetserver with pre-populated SIMP OMNI env' do

  config = {
    :domain                 => domain,
    :master_fqdn            => master_fqdn,
    :syslog_server_fqdns    => syslog_server_fqdns,
    :simp_scenario          => 'simp_lite',
    # we've already created the environment and deployed the modules
    :simp_config_extra_args => [ '--force-config' ]
  }

  include_examples 'SIMP server bootstrap', master, config
end
