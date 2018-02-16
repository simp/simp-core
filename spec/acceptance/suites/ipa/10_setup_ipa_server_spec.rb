require 'spec_helper_integration'

test_name 'set up an IPA server'

def skip_fips(host)
  if fips_enabled(host) && host.host_hash[:roles].include?('no_fips')
    return true
  else
    return false
  end
end

describe 'set up an IPA server' do
  domain         = fact_on(hosts_with_role(hosts, 'master').first, 'domain')
  admin_password = '@dm1n=P@ssw0r'
  ipa_domain     = 'test.case'
  ipa_realm      = ipa_domain.upcase
  ipa_fqdn       = fact_on(hosts_with_role(hosts, 'ipa-server').first, 'fqdn')
  ipa_ip         = fact_on(hosts_with_role(hosts, 'ipa-server').first, 'ipaddress_eth1')

  hosts.each do |host|
    # it 'should be running haveged for entropy' do
    #   # IPA requires entropy, so use haveged service
    #   on(host, 'puppet resource package haveged ensure=present')
    #   on(host, 'puppet resource service haveged ensure=running enable=true')
    # end
    it 'should install ipa client tools' do
      # Install the IPA client on all hosts
      on(host, 'puppet resource package ipa-client ensure=present')
      # Admintools for EL6
      on(host, 'puppet resource package ipa-admintools ensure=present', accept_all_exit_codes: true)
    end
    it 'should install ipa server packages' do
      on(host, 'puppet resource package ipa-server ensure=present')
      on(host, 'puppet resource package ipa-server-dns ensure=present')
    end
    # it 'should set up dnsmasq for now' do
    #   on(host, 'puppet resource package dnsmasq ensure=present')
    #   on(host, 'puppet resource service dnsmasq ensure=running enable=true')
    # end
    it 'should make sure the hostname is fully qualified' do
      fqdn = "#{host}.#{domain}"
      # Ensure that the hostname is set to the FQDN
      on(host, "hostname #{fqdn}")
      create_remote_file(host, '/etc/hostname', fqdn)
      create_remote_file(host, '/etc/sysconfig/network', <<-EOF.gsub(/ {10}/,'')
          NETWORKING=yes
          HOSTNAME=#{fqdn}
          PEERDNS=no
        EOF
      )
      host.reboot
    end
  end

  hosts_with_role(hosts, 'master').each do |master|
    it 'should munge the hieradata' do
      require 'yaml'
      existing = YAML.load(on(master, 'cat /etc/puppetlabs/code/environments/production/hieradata/default.yaml').stdout)
      hiera = existing.merge({
        'sssd::domains'               => ['LOCAL',ipa_domain],
        'simp_options::sssd'          => true,
        'simp_options::ldap'          => true,
        'simp_options::ldap::master'  => "ldap://#{ipa_fqdn}",
        'simp_options::ldap::uri'     => ["ldap://#{ipa_fqdn}"],
        'simp_options::ldap::base_dn' => 'gerbidge',
        'simp_options::ldap::bind_dn' => 'gerbidge',
        'simp_options::dns::servers'  => [ipa_ip],
        'simp_options::dns::search'   => [ipa_domain],
        'resolv::named_autoconf'      => false,
        'resolv::caching'             => false,
        'resolv::resolv_domain'       => ipa_domain,
        'sssd::services'              => [
          'nss',
          'pam',
          'ssh',
          'sudo',
          'autofs',
        ],
        'simp_options::uid::max'      => 0,
        'iptables::ports'             => {
          80  => nil,
          88  => nil,
          389 => nil,
          443 => nil,
          464 => nil,
          53  => { 'proto' => 'udp' },
          88  => { 'proto' => 'udp' },
          123 => { 'proto' => 'udp' },
          464 => { 'proto' => 'udp' },
        },
        'pam::access::users'          => {
          'defaults'   => {
            'origins'    => ['ALL'],
            'permission' => '+'
          },
          'testuser'     => nil,
          '(posixusers)' => nil
        },
        'ssh::server::conf::passwordauthentication' => true
        # 'simp::scenario::base::ldap'  => false,
        # 'class_exclusions'            => [
        #   'simp_nfs',
        #   'simp_grafana',
        #   'simp_openldap',
        #   'simp_openldap::client',
        # ]
      })
      create_remote_file(master, '/etc/puppetlabs/code/environments/production/hieradata/default.yaml', hiera.to_yaml)
    end
    # it 'should add a dnsaltname to the puppetserver cert' do
    #   on(master, 'puppet config set autosign true --section master')
    #   on(master, "puppet cert -c puppet.#{domain}")
    #   on(master, "puppet cert -g puppet.#{domain} --dns_alt_names=puppet.#{domain},puppet.#{ipa_domain},puppet", acceptable_exit_codes: [0,24])
    #   on(master, "puppet cert --allow-dns-alt-names sign puppet.#{ipa_domain}")
    # end
  end
  hosts.each do |host|
    it 'should run puppet to apply above changes' do
      # on(host, "puppet config set certname #{host}.#{domain}")
      on(host, 'puppet agent -t --server puppet', acceptable_exit_codes: [0,2,4,6])
    end
  end

  hosts_with_role(hosts, 'ipa-server').each do |ipa|
    it 'should bootstrap the IPA server' do
      # correct dns configuration
      on(ipa, 'service network restart')
      # remove existing ldap client configuration
      on(ipa, 'mv /etc/openldap/ldap.conf{,.bak}')
      on(ipa, 'mv /root/.ldaprc{,.bak}')

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
      on(ipa, cmd.join(' '))
      on(ipa, 'ipactl status')
    end
  end


  hosts_with_role(hosts, 'ipa-client').each do |client|
    next if skip_fips(client)

    context 'as an IPA client' do
      it 'should register with the IPA server' do
        fqdn = "#{client}.#{ipa_domain}"
        ipa_command = [
          # Unattended installation
          'ipa-client-install -U',
          # IPA directory domain
          "--domain=#{ipa_domain}",
          # IPA server to use
          "--server=#{ipa_fqdn}",
          # DNS settings
          '--enable-dns-updates',
          # Set hostname
          "--hostname=#{fqdn}",
          # Only point at this server and don't use SRV
          '--fixed-primary',
          # IPA krb5 realm
          "--realm=#{ipa_realm}",
          # Krb5 principal name to use
          '--principal=admin',
          # Admin password
          "--password='#{admin_password}'",
          # Don't update using authconfig
          '--noac'
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
