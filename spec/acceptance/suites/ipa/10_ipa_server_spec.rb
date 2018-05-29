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
  ipa_ip         = fact_on(ipa_server, 'ipaddress_eth1')

  context 'prepare ipa server' do
    it 'should install ipa-server' do
      on(ipa_server, 'puppet resource package ipa-server ensure=present')
      on(ipa_server, 'puppet resource package ipa-server-dns ensure=present')
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
    end
    it 'should reboot the server' do
      ipa_server.reboot
      retry_on(ipa_server, 'uptime', retry_interval: 15 )
    end
  end

  context 'classify nodes' do
    it 'modify the existing hieradata' do
      hiera = YAML.load(on(master, 'cat /etc/puppetlabs/code/environments/production/hieradata/default.yaml').stdout)
      default_yaml = hiera.merge(
        'simp_options::sssd'           => true,
        'simp_options::ldap'           => true,
        # 'simp_options::ldap::master'  => "ldap://#{ipa_fqdn}",
        # 'simp_options::ldap::uri'     => ["ldap://#{ipa_fqdn}"],
        # 'simp_options::ldap::base_dn' => 'gerbidge',
        # 'simp_options::ldap::bind_dn' => 'gerbidge',
        'simp_options::dns::servers'   => [ipa_ip],
        'simp_options::dns::search'    => [ipa_domain],
        'sssd::domains'                => ['LOCAL',ipa_domain],
        'resolv::named_autoconf'       => false,
        'resolv::caching'              => false,
        'resolv::resolv_domain'        => ipa_domain,
        # 'simp_options::uid::max'       => 2000000000,
        'pam::access::users'           => {
          'defaults'   => {
            'origins'    => ['ALL'],
            'permission' => '+'
          },
          'testuser'     => nil,
          '(posixusers)' => nil
        },
        'ssh::server::conf::passwordauthentication' => true,
      ).to_yaml
      create_remote_file(master, '/etc/puppetlabs/code/environments/production/hieradata/default.yaml', default_yaml)
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
    # it 'should add a dnsaltname to the puppetserver cert' do
    #   on(master, 'puppet config set autosign true --section master')
    #   on(master, "puppet cert -c puppet.#{domain}")
    #   on(master, "puppet cert -g puppet.#{domain} --dns_alt_names=puppet.#{domain},puppet.#{ipa_domain},puppet", acceptable_exit_codes: [0,24])
    #   on(master, "puppet cert --allow-dns-alt-names sign puppet.#{ipa_domain}")
    # end
  end

  context 'should run puppet to apply above changes' do
    it 'set up and run puppet' do
      block_on(agents, run_in_parallel: true) do |agent|
      # on(agent, "puppet config set certname #{agent}.#{domain}")
        retry_on(agent, 'puppet agent -t',
          desired_exit_codes: [0],
          retry_interval:     15,
          max_retries:        3,
          verbose:            true
        )
      end
    end
  end

  context 'IPA server prep' do
    it 'should bootstrap the IPA server' do
      # correct dns configuration
      # on(ipa_server, 'service network restart')

      # remove existing ldap client configuration
      on(ipa_server, 'mv /etc/openldap/ldap.conf{,.bak}', accept_all_exit_codes: true)
      on(ipa_server, 'mv /root/.ldaprc{,.bak}', accept_all_exit_codes: true)

      cmd = [
        'ipa-server-install',
        '--unattended',
        "--domain=#{ipa_domain}",
        "--realm=#{ipa_realm}",
        '--idstart=5000',
        '--setup-dns',
        '--forwarder=8.8.8.8',
        # '--auto-forwarders',
        '--auto-reverse',
        "--hostname=#{ipa_fqdn}",
        "--ip-address=#{ipa_ip}",
        '--ds-password="d1r3ct0ry=P@ssw0r"',
        "--admin-password='#{admin_password}'",
      ].join(' ')

      puts "\e[1;34m>>>>> The next step takes a very long time ... Please be patient! \e[0m"
      on(ipa_server, cmd)

      ipa_server.reboot
      on(ipa_server, 'ipactl status')
    end
  end

  context 'check connections to all hosts' do
    it 'reconnect' do
      # require 'pry';binding.pry
      # begin
      #   count ||= 0
      #   sleep count
      #   on(hosts, 'uptime')
      # rescue Beaker::Host::CommandFailure
      #   retry if (count += 1) < 3
      # end
      block_on(hosts) do |host|
        host.connection.connect
      end
    end
  end
end
