require_relative '../helpers'

include Acceptance::Helpers::RepoHelper
include Acceptance::Helpers::Utils

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
      set_up_simp_repos(host, set_up_simp_main, set_up_simp_deps) if set_up_simp_main || set_up_simp_deps

      install_puppet_repo(host) if options[:repos].include?(:puppet)

      on(host, 'yum clean all; yum makecache')
    end
  end

  it 'should ensure hostname is set to a FQDN' do
    # spec_helper_integration's ensure_fqdns sets this up; apps such as
    # rsyslog break without it
    fqdn = host_fqdn(host)
    expect(fqdn).to include('.')
    on(host, "hostnamectl set-hostname #{fqdn}")
  end

  # Some scripts (e.g. simp CLI) require Puppet's Ruby and more capable facts.
  it "should install the agent package to ensure Puppet's Ruby and facter are installed" do
    install_puppet_agent(host)
  end

  it 'should ensure FIPS mode is set per test' do
    if ENV['BEAKER_fips'] == 'yes' && !fips_enabled(host)
      enable_fips_mode_on(host)
    end
  end

end
