require 'spec_helper_integration'

test_name 'Configure and bootstrap SIMP puppetserver'

# facts gathered here are executed when the file first loads and
# use the factor gem temporarily installed into system ruby
master              = only_host_with_role(hosts, 'master')
master_fqdn         = host_fqdn(master)
syslog_servers      = hosts_with_role(hosts, 'syslog_server')
syslog_server_fqdns = syslog_servers.map { |server| host_fqdn(server) }
domain              = host_domain(master)

describe 'Configure and bootstrap SIMP puppetserver with pre-populated SIMP OMNI env' do

  config = {
    :domain                 => domain,
    :master_fqdn            => master_fqdn,
    :syslog_server_fqdns    => syslog_server_fqdns,
    # we've already created the environment and deployed the modules
    :simp_config_extra_args => [ '--force-config' ]
  }

  # BEAKER_extra_hieradata: a YAML (or JSON) Hash merged into the production
  # environment's data/default.yaml, e.g. to try a workaround on demand
  extra_hieradata = ENV.fetch('BEAKER_extra_hieradata', '').strip
  config[:other_hiera] = YAML.safe_load(extra_hieradata) unless extra_hieradata.empty?

  include_examples 'SIMP server bootstrap', master, config
end
