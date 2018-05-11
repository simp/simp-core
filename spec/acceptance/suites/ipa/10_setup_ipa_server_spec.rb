require 'spec_helper_integration'
require 'yaml'

test_name 'set up an IPA server'

def skip_fips(host)
  if fips_enabled(host) && host.host_hash[:roles].include?('no_fips')
    return true
  else
    return false
  end
end

describe 'set up an IPA server' do

  agents         = hosts_with_role(hosts, 'agent')
  ipa_server     = hosts_with_role(hosts, 'ipa_server').first
  ipa_clients    = hosts_with_role(hosts, 'ipa_client')
  master_fqdn    = fact_on(master, 'fqdn')
  domain         = fact_on(master, 'domain')

  admin_password = '@dm1n=P@ssw0r'
  ipa_domain     = 'test.case'
  ipa_realm      = ipa_domain.upcase
  ipa_fqdn       = fact_on(ipa_server, 'fqdn')
  ipa_ip         = fact_on(ipa_server, 'ipaddress_eth1')

  agents.each do |agent|
    context 'every node prep' do
      # it 'should be running haveged for entropy' do
      #   # IPA requires entropy, so use haveged service
      #   on(agent, 'puppet resource package haveged ensure=present')
      #   on(agent, 'puppet resource service haveged ensure=running enable=true')
      # end
      it 'should install ipa client tools' do
        # Install the IPA client on all hosts
        on(agent, 'puppet resource package ipa-client ensure=present')
        # Admintools for EL6
        on(agent, 'puppet resource package ipa-admintools ensure=present', accept_all_exit_codes: true)
      end
      # it 'should set up dnsmasq for now' do
      #   on(agent, 'puppet resource package dnsmasq ensure=present')
      #   on(agent, 'puppet resource service dnsmasq ensure=running enable=true')
      # end
      it 'should make sure the hostname is fully qualified' do
        fqdn = "#{agent}.#{domain}"
        # Ensure that the hostname is set to the FQDN
        on(agent, "hostname #{fqdn}")
        create_remote_file(agent, '/etc/hostname', fqdn)
        create_remote_file(agent, '/etc/sysconfig/network', <<-EOF.gsub(/^\s+/,'')
            NETWORKING=yes
            HOSTNAME=#{fqdn}
            PEERDNS=no
          EOF
        )
        agent.reboot
      end
    end
  end

  context 'classify nodes' do
    it 'modify the existing hieradata' do
      hiera = YAML.load(on(master, 'cat /etc/puppetlabs/code/environments/production/hieradata/default.yaml').stdout)
      default_yaml = hiera.merge(
        'simp_options::sssd'          => true,
        'simp_options::ldap'          => true,
        # 'simp_options::ldap::master'  => "ldap://#{ipa_fqdn}",
        # 'simp_options::ldap::uri'     => ["ldap://#{ipa_fqdn}"],
        # 'simp_options::ldap::base_dn' => 'gerbidge',
        # 'simp_options::ldap::bind_dn' => 'gerbidge',
        'simp_options::dns::servers'  => [ipa_ip],
        'simp_options::dns::search'   => [ipa_domain],
        'sssd::domains'               => ['LOCAL',ipa_domain],
        'resolv::named_autoconf'      => false,
        'resolv::caching'             => false,
        'resolv::resolv_domain'       => ipa_domain,
        'simp_options::uid::max'      => 0,
        'pam::access::users'          => {
          'defaults'   => {
            'origins'    => ['ALL'],
            'permission' => '+'
          },
          'testuser'     => nil,
          '(posixusers)' => nil
        },
        'ssh::server::conf::passwordauthentication' => true
      ).to_yaml
      create_remote_file(master, '/etc/puppetlabs/code/environments/production/hieradata/default.yaml', default_yaml)
    end

    it 'should open ports' do
      pp = <<-EOF
        iptables::listen::udp { 'ipa server':
          dports => [53,88,123,464]
        }
        iptables::listen::tcp_stateful { 'ipa server':
          dports => [53,80,88,389,443,464]
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

  agents.each do |agent|
    # on(agent, "puppet config set certname #{agent}.#{domain}")
    it 'should run puppet to apply above changes' do
      retry_on(agent, 'puppet agent -t',
        :desired_exit_codes => [0],
        :retry_interval     => 15,
        :max_retries        => 3,
        :verbose            => true
      )
    end
  end

  context 'IPA server prep' do
    it 'should bootstrap the IPA server' do
      # Install the server packages
      on(ipa_server, 'puppet resource package ipa-server ensure=present')
      on(ipa_server, 'puppet resource package ipa-server-dns ensure=present')

      # correct dns configuration
      on(ipa_server, 'service network restart')
      # remove existing ldap client configuration
      on(ipa_server, 'mv /etc/openldap/ldap.conf{,.bak}', :accept_all_exit_codes => true)
      on(ipa_server, 'mv /root/.ldaprc{,.bak}',           :accept_all_exit_codes => true)

      cmd = [
        'ipa-server-install',
        # IPA realm and domain do not have to match hostname
        "--domain #{ipa_domain}",
        '--setup-dns',
        '--forwarder=8.8.8.8',
        # '--no-reverse',
        # '--reverse-zone=229.255.10.in-addr.arpa.',
        "--realm #{ipa_realm}",
        "--hostname #{ipa_fqdn}",
        "--ip-address #{ipa_ip}",
        '--ds-password "d1r3ct0ry=P@ssw0r"',
        "--admin-password '#{admin_password}'",
        '--unattended',
        '--no-ui-redirect'
      ]
      puts "\e[1;34m>>>>> The next step takes a very long time ... Please be patient! \e[0m"
      on(ipa_server, cmd.join(' '))
      on(ipa_server, 'ipactl status')
    end
  end

  ipa_clients.each do |client|
    next if skip_fips(client)

    context 'as an IPA client' do
      it 'should register with the IPA server' do
        fqdn = "#{client}.#{ipa_domain}"
        ipa_command = [
          'ipa-client-install --unattended', # Unattended installation
          "--domain=#{ipa_domain}",          # IPA directory domain
          "--server=#{ipa_fqdn}",            # IPA server to use
          '--enable-dns-updates',            # DNS settings
          "--hostname=#{fqdn}",              # Set hostname
          '--fixed-primary',                 # Only point at this server and don't use SRV
          "--realm=#{ipa_realm}",            # IPA krb5 realm
          '--principal=admin',               # Krb5 principal name to use
          "--password='#{admin_password}'",  # Admin password
          '--noac'                           # Don't update using authconfig
        ].join(' ')

        on(client, ipa_command)
      end
      it 'should rename the FakeCA certs' do
        on(client, "cp /etc/pki/simp-testing/pki/private/* /etc/pki/simp-testing/pki/private/#{client}.#{ipa_domain}.pem")
        on(client, "cp /etc/pki/simp-testing/pki/public/* /etc/pki/simp-testing/pki/public/#{client}.#{ipa_domain}.pub")
      end
    end
  end
end
