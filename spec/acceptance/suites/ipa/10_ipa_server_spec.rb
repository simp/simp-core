require 'spec_helper_integration'
require 'yaml'

test_name 'set up an IPA server'

describe 'set up an IPA server' do

  agents     = hosts_with_role(hosts, 'agent')
  ipa_server = hosts_with_role(hosts, 'ipa_server').first
  domain     = fact_on(master, 'domain')

  ipa_domain     = domain
  ipa_realm      = ipa_domain.upcase
  ipa_fqdn       = fact_on(ipa_server, 'fqdn')
  ipa_ip         = ipa_server.reachable_name

  context 'prepare ipa server' do
    it 'ipa-server should have an internal network IP address' do
      expect(ipa_ip).to_not be_nil
    end

    it 'should install ipa-server' do
      result = on(ipa_server, 'cat /etc/oracle-release', :accept_all_exit_codes => true)
      if result.exit_code == 0
        # problem with OEL repos...need optional repos enabled in order
        # for all the dependencies of the ipa-server package to resolve
        ipa_server.install_package('yum-utils')
        on(ipa_server, 'yum-config-manager --enable ol7_optional_latest')
      end
      # forcing update of nss because ipa-server rpm has incorrect version dependency
      # this can be removed when rpm ipa-server --requires returns nss => 3.44.0
      ipa_server.upgrade_package('nss')
      ipa_server.install_package('ipa-server')
      ipa_server.install_package('ipa-server-dns')
    end

    it 'should make sure the hostname is fully qualified' do
      # TODO Is this additional configuration required?  We already set
      #   the hostname in the basic setup.  This does more by replacing
      #   the entire contents of the /etc/sysconfig/network file.
      fqdn = "#{ipa_server}.#{domain}"
      create_remote_file(ipa_server, '/etc/sysconfig/network', <<-EOF.gsub(/^\s+/,'')
          NETWORKING=yes
          HOSTNAME=#{fqdn}
          PEERDNS=no
        EOF
      )
    end

    it 'should have only fqdns in the hosts file' do
      on(ipa_server, 'puppet resource host ipa ensure=absent')
      on(ipa_server, 'cat /etc/hosts')
    end

    it 'should reboot the server' do
      ipa_server.reboot
      retry_on(ipa_server, 'uptime', :retry_interval => 15 )
    end
  end

  context 'configure nodes for the IPA services' do
    let(:files_dir) { 'spec/acceptance/common_files' }
    let(:site_module_path) {
      '/etc/puppetlabs/code/environments/production/modules/site'
    }

    let(:default_yaml_filename) {
      '/etc/puppetlabs/code/environments/production/data/default.yaml'
    }

    it 'should install a manifest to allow ports for IPA services' do
      # grab the whole site module even though we will only use site::ipa
      scp_to(master, "#{files_dir}/site", site_module_path)
      on(master, 'simp environment fix production --no-secondary-env --no-writable-env')
    end

    it 'should update default hiera to use IPA for DNS & allow ports for IPA services' do
      hiera = YAML.load(on(master, "cat #{default_yaml_filename}").stdout)
      updated_hiera = hiera.merge( {
        'simp_options::dns::servers'   => [ipa_ip],
        'simp_options::dns::search'    => [ipa_domain],
        'resolv::named_autoconf'       => false,
        'resolv::caching'              => false,
        'resolv::resolv_domain'        => ipa_domain
      } )

      # open up ports in iptables for IPA services
      updated_hiera['classes'] = [] unless updated_hiera.has_key?('classes')
      updated_hiera['classes'] << 'site::ipa'

      default_yaml = updated_hiera.to_yaml
      create_remote_file(master, default_yaml_filename, default_yaml)
      on(master, "cat #{default_yaml_filename}")
    end

    it 'should apply the configuration' do
      block_on(agents, :run_in_parallel => false) do |agent|
        retry_on(agent, 'puppet agent -t',
          :desired_exit_codes => [0],
          :retry_interval     => 15,
          :max_retries        => 3,
          :verbose            => true.to_s # work around beaker bug
        )
      end
    end
  end

  context 'IPA server prep' do
    it 'should bootstrap the IPA server that will also provide DNS' do
      # remove existing ldap client configuration
      on(ipa_server, 'mv /etc/openldap/ldap.conf{,.bak}', :accept_all_exit_codes => true)
      on(ipa_server, 'mv /root/.ldaprc{,.bak}', :accept_all_exit_codes => true)

      cmd  = []
      # Set umask for ipa test - detailed in Red Hat Bugzilla – Bug 1485217
      cmd << 'umask 0022 &&'
      cmd << 'ipa-server-install'
      cmd << '--unattended'
      cmd << "--domain=#{ipa_domain}"
      cmd << "--realm=#{ipa_realm}"

      # We have to tell IPA to use a reasonable UID/GID start number, or
      # IPA will generate it randomly and it can be in the billions (i.e.,
      # larger than the SIMP and SSSD default).
      cmd << '--idstart=5000'
      cmd << '--setup-dns'
      cmd << '--forwarder=8.8.8.8'
      cmd << '--auto-reverse' if ipa_server.host_hash[:platform] =~ /el-7/
      cmd << "--hostname=#{ipa_fqdn}"
      cmd << "--ip-address=#{ipa_ip}"
      cmd << "--ds-password='#{ipa_directory_service_password}'"
      cmd << "--admin-password='#{ipa_admin_password}'"

      puts "\e[1;34m>>>>> The next step takes a very long time ... Please be patient! \e[0m"
      on(ipa_server, cmd.join(' '))
      on(ipa_server, 'ipactl status')

      ipa_server.reboot

      # The IPA server has many services that take time to come up. So, we need
      # to make sure it is fully up before trying to access it. Unfortunately,
      # 'ipactl status' returns 0 even when individual components are stopped.
      # We have to scrape the command output to actually determine status.
      retry_on(ipa_server, "ipactl status | [ `grep -c STOPPED` == '0' ]",
        :retry_interval => 15 )

      on(ipa_server, 'ipactl status')
    end
  end
end
