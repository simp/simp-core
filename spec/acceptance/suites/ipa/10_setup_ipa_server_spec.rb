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
  admin_password = '@dm1n=P@ssw0r'
  ipa_domain     = 'test.case'
  ipa_realm      = ipa_domain.upcase
  ipa_fqdn       = fact_on(hosts_with_role(hosts, 'ipa-server').first, 'fqdn')

  hosts.each do |host|
    it 'should be running haveged for entropy' do
      # IPA requires entropy, so use haveged service
      on(host, 'puppet resource package haveged ensure=present')
      on(host, 'puppet resource service haveged ensure=running enable=true')
    end
    it 'should install ip client tools' do
      # Install the IPA client on all hosts
      on(host, 'puppet resource package ipa-client ensure=present')

      # Admintools for EL6
      on(host, 'puppet resource package ipa-admintools ensure=present', :accept_all_exit_codes => true)
    end
    it 'should make sure the hostname is fully qualified' do
      fqdn = fact_on(host, 'fqdn')
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
        'iptables::ports'             => {
          80  => nil,
          88  => nil,
          389 => nil,
          443 => nil,
          464 => nil,
        },
        'pam::access::users'          => {
          'defaults'   => {
            'origins'    => ['ALL'],
            'permission' => '+'
          },
          'testuser'   => nil,
          '(ipausers)' => nil
        }
      })
      create_remote_file(master, '/etc/puppetlabs/code/environments/production/hieradata/default.yaml', hiera.to_yaml)
    end
  end
  hosts.each do |host|
    it 'should run puppet to apply above changes' do
      on(host, 'puppet agent -t', :acceptable_exit_codes => [0,2,4,6])
    end
  end

  hosts_with_role(hosts, 'ipa-server').each do |ipa|
    it 'should bootstrap the IPA server' do
      on(ipa, 'puppet resource package ipa-server ensure=present')
      on(ipa, 'puppet resource package ipa-server-dns ensure=present')
      cmd = [
        'ipa-server-install',
        # IPA realm and domain do not have to match hostname
        "--domain #{ipa_domain}",
        # '--setup-dns',
        # '--forwarder=8.8.8.8',
        # '--no-reverse',
        # '--reverse-zone=229.255.10.in-addr.arpa.',
        "--realm #{ipa_realm}",
        "--hostname #{ipa_fqdn}",
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
        ipa_command = [
          # Unattended installation
          'ipa-client-install -U',
          # IPA directory domain
          "--domain=#{ipa_domain}",
          # IPA server to use
          "--server=#{ipa_fqdn}",
          # DNS settings
          '--enable-dns-updates',
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
    end
  end
end
