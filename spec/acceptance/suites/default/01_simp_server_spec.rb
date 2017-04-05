require 'spec_helper_integration'

test_name 'puppetserver via r10k'

describe 'install environment via r10k and puppetserver' do

  masters     = hosts_with_role(hosts, 'master')
  agents      = hosts_with_role(hosts, 'agent')
  master_fqdn = fact_on(master, 'fqdn')
  master_manifest = <<-EOF
    # Set up a puppetserver
    class { 'pupmod::master':
      firewall     => true,
      trusted_nets => ['ALL'],
    }
    # pupmod::master::autosign { '*': entry => '*' }
    exec { 'set autosign':
      command => '/opt/puppetlabs/bin/puppet config --section master set autosign true',
      unless  => '/opt/puppetlabs/bin/puppet config --section master print autosign | grep true'
    }

    # Maintain connection to the VM
    pam::access::rule { 'vagrant_all':
      users      => ['vagrant'],
      permission => '+',
      origins    => ['ALL'],
    }
    sudo::user_specification { 'vagrant':
      user_list => ['vagrant'],
      cmnd      => ['ALL'],
      passwd    => false,
    }
    sshd_config { 'PermitRootLogin'    : value => 'yes' }
    sshd_config { 'AuthorizedKeysFile' : value => '.ssh/authorized_keys' }
    include 'tcpwrappers'
    include 'iptables'
    tcpwrappers::allow { 'sshd': pattern => 'ALL' }
    iptables::listen::tcp_stateful { 'allow_ssh':
      trusted_nets => ['ALL'],
      dports       => 22
    }
  EOF

  hosts.each do |host|
    it 'should set the root password' do
      on(host, "sed -i 's/enforce_for_root//g' /etc/pam.d/*")
      on(host, 'echo password | passwd root --stdin')
    end
    it 'should set up needed repositories' do
      host.install_package('epel-release')
      on(host, 'curl -s https://packagecloud.io/install/repositories/simp-project/6_X_Dependencies/script.rpm.sh | bash')
    end
    it 'should install the r10k gem' do
      master.install_package('git')
      on(master, 'puppet resource package r10k ensure=present provider=puppet_gem')
    end
  end

  context 'master' do
    masters.each do |master|
      master.install_package('wget')
      moduledir = create_tmpdir_on(master)
      deps = [ 'pupmod-simp-pupmod','pupmod-simp-pam','pupmod-simp-sudo','pupmod-simp-simplib','pupmod-simp-simpcat','pupmod-simp-iptables','pupmod-simp-tcpwrappers','augeasproviders_ssh','augeasproviders_core','puppetlabs-stdlib','puppetlabs-inifile','puppetlabs-concat','puppet-haveged']
      it 'should install base modules for pupmod' do
        on(master, 'mkdir -p /tmp/module-tars /tmp/modules')
        deps.each do |dep|
          on(master, <<-EOF
              wget https://github.com/simp/#{dep}/archive/master.tar.gz -O /tmp/module-tars/#{dep}.tar.gz
              puppet module install /tmp/module-tars/#{dep}.tar.gz --ignore-dependencies --target-dir=#{moduledir}
            EOF
          )
        end
      end
      it 'should set up a puppetserver' do
        apply_manifest_on(master, master_manifest, :modulepath => moduledir, :accept_all_exit_codes => true)
        apply_manifest_on(master, master_manifest, :modulepath => moduledir, :accept_all_exit_codes => true)
        master.reboot
        apply_manifest_on(master, master_manifest, :modulepath => moduledir, :catch_failures => true)
      end
      it 'should be idempotent' do
        apply_manifest_on(master, master_manifest, :modulepath => moduledir, :catch_changes => true )
      end
      it 'should enable trusted_server_facts' do
        on(master, 'puppet config --section master set trusted_server_facts true')
      end
    end
  end

  context 'install modules via r10k' do
    it 'scp a Puppetfile to $codedir' do
      scp_to(master, 'spec/acceptance/suites/default/files/Puppetfile', '/etc/puppetlabs/code/environments/production/Puppetfile')
    end
    it 'should install the Puppetfile' do
      on(master, 'cd /etc/puppetlabs/code/environments/production; /opt/puppetlabs/puppet/bin/r10k puppetfile install', :accept_all_exit_codes => true)
      on(master, 'cd /etc/puppetlabs/code/environments/production; /opt/puppetlabs/puppet/bin/r10k puppetfile install')
      on(master, 'chown -R root.puppet /etc/puppetlabs/code/environments/production/modules')
      on(master, 'chmod -R g+rX /etc/puppetlabs/code/environments/production/modules')
    end

  end

  context 'classify nodes' do
    site_pp = <<-EOF
      node default {
        include 'simp'
      }
      node /puppet/ {
        include 'simp'
        include 'simp::server'
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
      simp_options::ldap::bind_pw: 's00per sekr3t!'
      simp_options::ldap::bind_hash: '{SSHA}foobarbaz!!!!'
      simp_options::ldap::sync_pw: 's00per sekr3t!'
      simp_options::ldap::sync_hash: '{SSHA}foobarbaz!!!!'
      simp_options::ldap::root_hash: '{SSHA}foobarbaz!!!!'
      simp_options::auditd: true
      simp_options::fips: false
      fips::enabled: false # TODO remove when fips pr is merged
      simp_options::haveged: true
      simp_options::logrotate: true
      simp_options::pam: true
      simp_options::selinux: true
      simp_options::stunnel: true
      simp_options::tcpwrappers: true
      simp_options::firewall: true

      # simp_options::log_servers: ['#{master_fqdn}']
      sssd::domains: ['LOCAL']
      simp::yum::servers: ['#{master_fqdn}']

      # Settings required for acceptance test, some may be required
      simp::scenario: simp
      simp_options::clamav: false
      simp_options::pki: true
      simp_options::pki::source: '/etc/pki/simp-testing/pki'
      simp_options::trusted_nets: ['ALL']
      simp::yum::os_update_url: http://mirror.centos.org/centos/$releasever/os/$basearch/
      simp::yum::enable_simp_repos: false
      simp::scenario::base::puppet_server_hosts_entry: false
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
    it 'should install the control repo' do
      on(master, 'mkdir -p /etc/puppetlabs/code/environments/production/{hieradata,manifests} /var/simp/environments/production/{simp_autofiles,site_files/modules/pki_files/files/keydist}')
      scp_to(master, 'spec/acceptance/suites/default/files/hiera.yaml', '/etc/puppetlabs/puppet/hiera.yaml')
      create_remote_file(master, '/etc/puppetlabs/code/environments/production/manifests/site.pp', site_pp)
      create_remote_file(master, '/etc/puppetlabs/code/environments/production/hieradata/default.yaml', default_yaml)
      on(master, 'chown -R root.puppet /etc/puppetlabs/code/environments/production/{hieradata,manifests} /var/simp/environments/production/site_files/modules/pki_files/files/keydist')
      on(master, 'chmod -R g+rX /etc/puppetlabs/code/environments/production/{hieradata,manifests} /var/simp/environments/production/site_files/modules/pki_files/files/keydist')
      on(master, 'chown -R puppet.puppet /var/simp/environments/production/simp_autofiles')
      on(master, 'puppet resource service puppetserver ensure=running')
    end
  end

  context 'agents' do
    agents.each do |agent|
      it 'should run the agent' do
        # require 'pry';binding.pry if fact_on(agent, 'hostname') == 'agent'
        on(agent, "puppet agent -t --ca_port 8141 --server #{master_fqdn}", :acceptable_exit_codes => [0,2,4,6])
        sleep(30)
        on(agent, "puppet agent -t --ca_port 8141 --server #{master_fqdn}", :acceptable_exit_codes => [0,2,4,6])
        agent.reboot
        sleep(240)
        on(agent, "puppet agent -t --ca_port 8141 --server #{master_fqdn}", :acceptable_exit_codes => [0,2])
      end
      it 'should be idempotent' do
        sleep(30)
        on(agent, 'puppet agent -t', :acceptable_exit_codes => [0])
      end
    end
  end

end
