require_relative '../helpers'

include Acceptance::Helpers::RepoHelper
include Acceptance::Helpers::SystemGemHelper

# options keys:
#   :root_password - plain text password for the root user
#   :repos         - array of repos to install; valid values are
#                    :epel      - epel-release repo
#                    :simp      - SIMP internet repo
#                    :simp_deps - SIMP dependencies internet repo
#                    :puppet    - Puppet collection repo
shared_examples 'basic server setup' do |host, options|

  it 'should set the root password and configure root PAM access' do
    # set the root password
    if options.has_key?(:root_password)
      password = options[:root_password]
    else
      password = 'P@sswordP@ssword!'
    end

    on(host, "sed -i 's/enforce_for_root//g' /etc/pam.d/*")
    on(host, "echo '#{password}' | passwd root --stdin")
  end

  it 'should install necessary repos' do
    if options.has_key?(:repos) && !options[:repos].empty?
      host.install_package('epel-release') if options[:repos].include?(:epel)

      set_up_simp_main = options[:repos].include?(:simp)
      set_up_simp_deps = options[:repos].include?(:simp_deps)
      set_up_simp_repos(host, set_up_simp_main, set_up_simp_deps)

      install_puppet_repo(host) if options[:repos].include?(:puppet)

      on(host, 'yum clean all; yum makecache')
    end
  end

  it 'should ensure hostname is set to a FQDN' do
    # FQDN fact seems to be correct even though all the places hostname must
    # be set may not be. This can break apps such as rsyslog.
    fqdn = fact_on(host, 'fqdn')
    on(host, "hostname #{fqdn}")
    on(host, "echo #{fqdn} > /etc/hostname")
    on(host, "sed -i '/HOSTNAME/d' /etc/sysconfig/network")
    on(host, "echo HOSTNAME=#{fqdn} >> /etc/sysconfig/network")
  end

  # Some scripts (e.g. simp CLI) require Puppet's Ruby and more capable facts.
  it "should install puppet-agent to ensure Puppet's Ruby and facter are installed" do
    # will install a specific puppet-agent version if PUPPET_VERSION is set
    puppet_version = latest_puppet_agent_version_for(ENV['PUPPET_VERSION'])
    host.install_package('puppet-agent', '', puppet_version)
  end

  it 'should remove temporary system factor gem required for beaker host prep' do
    uninstall_system_factor_gem(host)
  end

  it 'should ensure FIPS mode is set per test' do
    if ENV['BEAKER_fips'] == 'yes' && !fips_enabled(host)
      enable_fips_mode_on(host)
    end
  end

end
