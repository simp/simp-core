require 'spec_helper_integration'
require 'yaml'

test_name 'set up an IPA server'

describe 'set up an IPA server' do

  agents     = hosts_with_role(hosts, 'agent')
  ipa_server = hosts_with_role(hosts, 'ipa_server').first
  domain     = fact_on(master, 'domain')

  admin_password = '@dm1n=P@ssw0r'
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
      ipa_server.install_package('ipa-server')
      ipa_server.install_package('ipa-server-dns')
      if ipa_server.host_hash[:platform] =~ /el-6/
        ipa_server.install_package('bind')
        ipa_server.install_package('bind-dyndb-ldap')
      end
    end

    it 'should make sure the hostname is fully qualified' do
      fqdn = "#{ipa_server}.#{domain}"
      on(ipa_server, "hostname #{fqdn}")
      create_remote_file(ipa_server, '/etc/hostname', fqdn)
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

  context 'classify nodes' do
    it 'modify the existing hieradata' do
      hiera = YAML.load(on(master, 'cat /etc/puppetlabs/code/environments/production/data/default.yaml').stdout)
      default_yaml = hiera.merge(
        'simp_options::sssd'           => true,
        'simp_options::ldap'           => true,
        'simp_options::dns::servers'   => [ipa_ip],
        'simp_options::dns::search'    => [ipa_domain],
        'sssd::domains'                => ['LOCAL',ipa_domain],
        'resolv::named_autoconf'       => false,
        'resolv::caching'              => false,
        'resolv::resolv_domain'        => ipa_domain,
        'pam::access::users'           => {
          'defaults'   => {
            'origins'    => ['ALL'],
            'permission' => '+'
          },
          'vagrant'      => nil,
          'testuser'     => nil,
          '(posixusers)' => nil,
        },
        'ssh::server::conf::passwordauthentication' => true,
        'sudo::user_specifications' => {
          'vagrant_sudo_nopasswd' => {
            'user_list' => ['vagrant'],
            'cmnd'      => ['ALL'],
            'runas'     => 'root',
            'passwd'    => false,
          }
        }
      ).to_yaml
      create_remote_file(master, '/etc/puppetlabs/code/environments/production/data/default.yaml', default_yaml)
    end

    it 'should open ports' do
      pp = <<-EOF
        iptables::listen::udp { 'ipa server':
          dports => [53,88,123,464]
        }
        iptables::listen::tcp_stateful { 'ipa server':
          dports => [53,80,88,389,443,464,636]
        }
      EOF
      create_remote_file(master, '/etc/puppetlabs/code/environments/production/manifests/ipa-iptables.pp', pp)
      on(master, 'chown root.puppet /etc/puppetlabs/code/environments/production/manifests/*')
      on(master, 'chmod g+rX /etc/puppetlabs/code/environments/production/manifests/*')
    end
  end

  context 'should run puppet to apply above changes' do
    it 'set up and run puppet' do
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
    it 'should bootstrap the IPA server' do
      # remove existing ldap client configuration
      on(ipa_server, 'mv /etc/openldap/ldap.conf{,.bak}', :accept_all_exit_codes => true)
      on(ipa_server, 'mv /root/.ldaprc{,.bak}', :accept_all_exit_codes => true)

      cmd  = []
      cmd << 'ipa-server-install'
      cmd << '--unattended'
      cmd << "--domain=#{ipa_domain}"
      cmd << "--realm=#{ipa_realm}"
      cmd << '--idstart=5000'
      cmd << '--setup-dns'
      cmd << '--forwarder=8.8.8.8'
      cmd << '--auto-reverse' if ipa_server.host_hash[:platform] =~ /el-7/
      cmd << "--hostname=#{ipa_fqdn}"
      cmd << "--ip-address=#{ipa_ip}"
      cmd << '--ds-password="d1r3ct0ry=P@ssw0r"'
      cmd << "--admin-password='#{admin_password}'"

      puts "\e[1;34m>>>>> The next step takes a very long time ... Please be patient! \e[0m"
      on(ipa_server, cmd.join(' '))

      ipa_server.reboot
      on(ipa_server, 'ipactl status')
    end
  end
end
