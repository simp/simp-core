require 'spec_helper_integration'
require 'json'

test_name 'simp::server::rsync_shares'

describe 'install rsync from GitHub (not rpm) and test simp::server::rsync_shares' do

  masters     = hosts_with_role(hosts, 'master')
  agents      = hosts_with_role(hosts, 'agent')
  master_fqdn = fact_on(master, 'fqdn')

  context 'master' do
    masters.each do |master|
      it 'should prepare the rsync server environment' do
        tmpdir = create_tmpdir_on(master)
        # master.install_package('selinux-policy-devel')

        script = <<-EOF
          mkdir -p /var/simp/environments/simp/rsync
          git clone https://github.com/simp/simp-rsync.git #{tmpdir}
          rm -rf /var/simp/environments/{simp,production}/rsync
          mv -f #{tmpdir}/environments/simp/rsync /var/simp/environments/production/
          ln -s /var/simp/environments/production/rsync/RedHat /var/simp/environments/production/rsync/CentOS
          chmod u+rwx,g+rX,o+rX /var/simp{,/environments,/environments/production}

          # SELinux fixes
          # setfacl --restore=/var/simp/environments/production/rsync/.rsync.facl 2>/dev/null
          # cd #{tmpdir}/build/selinux; make -f /usr/share/selinux/devel/Makefile
          # cp #{tmpdir}/build/selinux/simp-rsync.pp /usr/share/selinux/packages
          # semodule -n -i /usr/share/selinux/packages/simp-rsync.pp
          # load_policy
          # fixfiles -R simp-rsync restore
        EOF
        on(master, script)
      end
      it 'should mock freshclam' do
        master.install_package('clamav-update')
        # create_remote_file(master, '/tmp/freshclam.conf', <<-EOF.gsub(/^\s+/,'')
        #     DatabaseDirectory /var/simp/environments/production/rsync/Global/clamav
        #     DatabaseMirror database.clamav.net
        #     Bytecode yes
        #   EOF
        # )
        # on(master, 'freshclam -u root --config-file=/tmp/freshclam.conf')
        on(master, 'touch /var/simp/environments/production/rsync/Global/clamav/{daily,bytecode,main}.cvd')
        # on(master, 'chown clam.clam /var/simp/environments/production/rsync/Global/clamav/*')
        # on(master, 'chmod u=rw,g=rw,o=r /var/simp/environments/production/rsync/Global/clamav/*')
      end

      it 'classify nodes' do
        default_yaml = <<-EOF
          # Options
          simp_options::dns::servers: ['8.8.8.8']
          simp_options::puppet::server: #{master_fqdn}
          simp_options::puppet::ca: #{master_fqdn}
          simp_options::ntpd::servers: ['time.nist.gov']
          simp_options::ldap::bind_pw: 's00per sekr3t!'
          simp_options::ldap::bind_hash: '{SSHA}foobarbaz!!!!'
          simp_options::ldap::sync_pw: 's00per sekr3t!'
          simp_options::ldap::sync_hash: '{SSHA}foobarbaz!!!!'
          simp_options::ldap::root_hash: '{SSHA}foobarbaz!!!!'
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
        create_remote_file(master, '/etc/puppetlabs/code/environments/production/hieradata/default.yaml', default_yaml)
      end
      it 'should configure the system' do
        on(master, 'puppet agent -t', :acceptable_exit_codes => [0,2,4,6])
        on(master, 'puppet agent -t', :acceptable_exit_codes => [0,2])
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
