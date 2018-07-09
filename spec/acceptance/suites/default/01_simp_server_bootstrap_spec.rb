require 'spec_helper_integration'
require 'beaker/puppet_install_helper'
require 'yaml'

test_name 'puppetserver'

describe 'install puppetserver from puppet modules' do

  agents      = hosts_with_role(hosts, 'agent')
  master_fqdn = fact_on(master, 'fqdn')
  puppetserver_status_cmd = [
    'curl -sk',
    "--cert /etc/puppetlabs/puppet/ssl/certs/#{master_fqdn}.pem",
    "--key /etc/puppetlabs/puppet/ssl/private_keys/#{master_fqdn}.pem",
    "https://#{master_fqdn}:8140/status/v1/services",
    '| python -m json.tool',
    '| grep state',
    '| grep running'
  ].join(' ')

  master_manifest = <<-EOF
    # Use our puppet module to set up puppetserver
    class { 'pupmod::master':
      firewall     => true,
      trusted_nets => ['0.0.0.0/0'],
      log_level    => 'INFO'
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

  context 'bootstrap simp server' do
    it 'should set up a simp server' do
       apply_manifest_on(master, master_manifest, :accept_all_exit_codes => true)
       apply_manifest_on(master, master_manifest, :accept_all_exit_codes => true)
       master.reboot
       apply_manifest_on(master, master_manifest, :catch_failures => true)
     end
     it 'should be idempotent' do
       apply_manifest_on(master, master_manifest, :catch_changes => true )
     end
  end

  context 'classify nodes' do
    site_pp = <<-EOF
      # All nodes
      node default {
        include 'simp_options'
        include 'simp'
      }
      # The puppetserver
      node /puppet/ {
        include 'simp_options'
        include 'simp'
        include 'simp::server'
        include 'pupmod'
        include 'pupmod::master'
      }
    EOF

    yaml         = YAML.load(File.read('spec/acceptance/suites/default/files/default.yaml'))
    default_yaml = yaml.merge(
      'simp_options::puppet::server' => master_fqdn,
      'simp_options::puppet::ca'     => master_fqdn,
      'simp::yum::servers'           => [master_fqdn]
    ).to_yaml

    it 'should install the control repo' do
      on(master, 'mkdir -p /etc/puppetlabs/code/environments/production/{hieradata,manifests} /var/simp/environments/production/{simp_autofiles,site_files/modules/pki_files/files/keydist}')

      scp_to(master, 'spec/acceptance/suites/default/files/hiera.yaml', '/etc/puppetlabs/puppet/hiera.yaml')
      create_remote_file(master, '/etc/puppetlabs/code/environments/production/manifests/site.pp', site_pp)
      create_remote_file(master, '/etc/puppetlabs/code/environments/production/hieradata/default.yaml', default_yaml)

      on(master, 'chown -R root.puppet /etc/puppetlabs/code/environments/production/{hieradata,manifests} /var/simp/environments/production/site_files/modules/pki_files/files/keydist')
      on(master, 'chmod -R g+rX /etc/puppetlabs/code/environments/production/{hieradata,manifests} /var/simp/environments/production/site_files/modules/pki_files/files/keydist')
      on(master, 'chown -R puppet.puppet /var/simp/environments/production/simp_autofiles')

      on(master, 'puppet resource service puppetserver ensure=stopped')
      on(master, 'puppet resource service puppetserver ensure=running')

      on(master, 'puppet generate types', :accept_all_exit_codes => true)
      retry_on(master, puppetserver_status_cmd, :retry_interval => 10)
    end
  end

  context 'agents' do
    it 'set up and run puppet' do
      block_on(agents, :run_in_parallel => false) do |agent|
        on(agent, "puppet config set server #{master_fqdn}")
        on(agent, 'puppet config set masterport 8140')
        on(agent, 'puppet config set ca_port 8141')

        # Run puppet and expect changes
        retry_on(agent, 'puppet agent -t',
          :desired_exit_codes => [0,2],
          :retry_interval     => 15,
          :max_retries        => 5,
          :verbose            => true
        )

        # Reboot and wait for machine to come back up
        agent.reboot
        retry_on(master, puppetserver_status_cmd, :retry_interval => 10)
        retry_on(agent, 'uptime', :retry_interval => 15 )

        # Wait for things to settle and stop making changes
        retry_on(agent, 'puppet agent -t',
          :desired_exit_codes => [0],
          :retry_interval     => 15,
          :max_retries        => 3,
          :verbose            => true
        )
      end
    end
  end
end
