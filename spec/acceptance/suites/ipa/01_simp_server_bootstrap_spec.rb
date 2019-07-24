require 'spec_helper_integration'

test_name 'Configure and bootstrap SIMP puppetserver'

# facts gathered here are executed when the file first loads and
# use the factor gem temporarily installed into system ruby
master              = only_host_with_role(hosts, 'master')
master_fqdn         = fact_on(master, 'fqdn')
syslog_servers      = hosts_with_role(hosts, 'syslog_server')
syslog_server_fqdns = syslog_servers.map { |server| fact_on(server, 'fqdn') }
domain              = fact_on(master, 'domain')

describe 'Configure and bootstrap SIMP puppetserver with pre-populated SIMP OMNI env & excluding SIMP LDAP server' do

  config = {
    :domain                 => domain,
    :master_fqdn            => master_fqdn,
    :syslog_server_fqdns    => syslog_server_fqdns,

    # we've already created the environment and deployed the modules
    :simp_config_extra_args => [ '--force-config' ],

    # we're going to use IPA for user accounts
    :simp_ldap_server       => false,
    :other_hieradata        => {
      # We have to turn on LDAP support manually.  It is not
      # enabled by default in the 'simp' or 'simp_lite' scenarios.
      'simp_options::ldap'            => true,

      # The following parameters are required by simp_options::ldap, even
      # though they are **not** # currently used. (IPA doesn't come with
      # native BIND or SYNC DNs.)
      'simp_options::ldap::bind_hash' => '{SSHA}zzIihXlCUh9ejl6mGhIPyvIfG8I8yTsL',
      'simp_options::ldap::bind_pw'   => 'm-Y2PFhrUE6Y.dx0joLicL%IUm5I9TtO',
      'simp_options::ldap::sync_hash' => '{SSHA}oeKnIem05NR8lTVonEdj+TBIryxdhNal',
      'simp_options::ldap::sync_pw'   => 'OLIffaIr5pkZgvLYfqR%2W6+VtQvlAjy'
    }
  }

  include_examples 'SIMP server bootstrap', master, config
end
