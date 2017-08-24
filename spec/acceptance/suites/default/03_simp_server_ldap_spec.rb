require 'spec_helper_integration'

test_name 'simp::server::ldap'

describe 'use the simp::server::ldap class to create and ldap environment' do
  masters     = hosts_with_role(hosts, 'master')
  agents      = hosts_with_role(hosts, 'agent')
  master_fqdn = fact_on(master, 'fqdn')

  context 'master' do
    masters.each do |master|
      it 'classify nodes' do
        site_pp = <<-EOF
          node default {
            include 'simp_options'
            include 'simp'
          }
          node /puppet/ {
            include 'simp_options'
            include 'simp'
            include 'simp::server'
            include 'simp::server::ldap'
            include 'simp::server::rsync_shares'
            include 'pupmod'
            include 'pupmod::master'
          }
        EOF
        default_yaml = <<-EOF
          # Options
          simp_options::dns::servers: ['8.8.8.8']
          simp_options::puppet::server: #{master_fqdn}
          simp_options::puppet::ca: #{master_fqdn}
          simp_options::ntpd::servers: ['time.nist.gov']
          simp_options::ldap::bind_pw: 's00persekr3t!'
          simp_options::ldap::bind_hash: '{SSHA}foobarbaz!!!!'
          simp_options::ldap::sync_pw: 's00persekr3t!'
          simp_options::ldap::sync_hash: '{SSHA}foobarbaz!!!!'
          simp_options::ldap::root_hash: '{SSHA}foobarbaz!!!!'
          simp_openldap::server::conf::rootpw: 's00persekr3t!'
          # simp_options::ldap::uri: ['ldap://#{master_fqdn}']
          # simp_options::ldap::uri: #{master_fqdn}
          simp_options::ldap: true
          simp_options::sssd: true
          simp_options::auditd: true
          simp_options::haveged: true
          simp_options::fips: false
          fips::enabled: false # TODO remove when fips pr is merged
          simp_options::pam: true
          simp_options::logrotate: true
          simp_options::selinux: true
          simp_options::tcpwrappers: true
          simp_options::stunnel: true
          simp_options::firewall: true

          # simp_options::log_servers: ['#{master_fqdn}']
          sssd::domains: ['LOCAL']
          simp::yum::servers: ['#{master_fqdn}']

          # Settings required for acceptance test, some may be required
          simp::scenario: simp
          simp_options::rsync: true
          simp_options::clamav: true
          simp_options::pki: true
          simp_options::pki::source: '/etc/pki/simp-testing/pki'
          simp_options::trusted_nets: ['10.0.0.0/8']
          simp::yum::os_update_url: http://mirror.centos.org/centos/$releasever/os/$basearch/
          simp::yum::enable_simp_repos: false
          simp::scenario::base::puppet_server_hosts_entry: false
          simp::scenario::base::rsync_stunnel: #{master_fqdn}

          # Make sure puppet doesn't run (hopefully)
          pupmod::agent::cron::minute: '0'
          pupmod::agent::cron::hour: '0'
          pupmod::agent::cron::weekday: '0'
          pupmod::agent::cron::month: '1'

          # Settings to make beaker happy
          sudo::user_specifications:
            vagrant_all:
              user_list: ['vagrant']
              cmnd: ['ALL']
              passwd: false
          pam::access::users:
            defaults:
              origins:
                - ALL
              permission: '+'
            vagrant:
          ssh::server::conf::permitrootlogin: true
          ssh::server::conf::authorizedkeysfile: .ssh/authorized_keys
        EOF
        create_remote_file(master, '/etc/puppetlabs/code/environments/production/manifests/site.pp', site_pp)
        create_remote_file(master, '/etc/puppetlabs/code/environments/production/hieradata/default.yaml', default_yaml)
      end
      it 'should configure the system' do
        on(master, 'puppet agent -t', :acceptable_exit_codes => [0,2,4,6])
        Simp::TestHelpers.wait(30)
        retry_on(master, 'puppet agent -t', :desired_exit_codes => [0,2], :max_retries => 3, :retry_interval => 20)
      end
      it 'should be idempotent' do
        on(master, 'puppet agent -t', :acceptable_exit_codes => [0])
      end
    end
  end

  context 'agents' do
    agents.each do |agent|
      it 'should configure the system' do
        on(agent, 'puppet agent -t', :acceptable_exit_codes => [0,2,4,6])
        on(agent, 'puppet agent -t', :acceptable_exit_codes => [0,2])
      end
      it 'should be idempotent' do
        on(agent, 'puppet agent -t', :acceptable_exit_codes => [0])
      end
    end
  end

end
