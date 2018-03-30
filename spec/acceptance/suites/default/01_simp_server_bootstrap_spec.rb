require 'spec_helper_integration'
require 'beaker/puppet_install_helper'
require 'yaml'

test_name 'puppetserver via PuppetForge'

describe 'install puppetserver from PuppetForge' do

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
      node default {
        include 'simp'
      }
      node /puppet/ {
        include 'simp'
        include 'simp::server'
        include 'pupmod'
        include 'pupmod::master'
      }
    EOF

    yaml = YAML.load(File.read('spec/acceptance/suites/default/files/default.yaml'))
    default_yaml = yaml.merge(
      'simp_options::puppet::server' => master_fqdn,
      'simp_options::puppet::ca'     => master_fqdn,
      'simp::yum::servers'           => [master_fqdn]
    )

    it 'should install the control repo' do
      on(master, 'mkdir -p /etc/puppetlabs/code/environments/production/{hieradata,manifests} /var/simp/environments/production/{simp_autofiles,site_files/modules/pki_files/files/keydist}')
      scp_to(master, 'spec/acceptance/suites/default/files/hiera.yaml', '/etc/puppetlabs/puppet/hiera.yaml')
      create_remote_file(master, '/etc/puppetlabs/code/environments/production/manifests/site.pp', site_pp)
      create_remote_file(master, '/etc/puppetlabs/code/environments/production/hieradata/default.yaml', default_yaml.to_yaml)
      on(master, 'chown -R root.puppet /etc/puppetlabs/code/environments/production/{hieradata,manifests} /var/simp/environments/production/site_files/modules/pki_files/files/keydist')
      on(master, 'chmod -R g+rX /etc/puppetlabs/code/environments/production/{hieradata,manifests} /var/simp/environments/production/site_files/modules/pki_files/files/keydist')
      on(master, 'chown -R puppet.puppet /var/simp/environments/production/simp_autofiles')
      on(master, 'puppet resource service puppetserver ensure=running')
    end
  end

  context 'agents' do
    agents.each do |agent|
      it "should run the agent on #{agent}" do
        # require 'pry';binding.pry if fact_on(agent, 'hostname') == 'agent'
        on(agent, "puppet agent -t --ca_port 8141 --server #{master_fqdn}", :acceptable_exit_codes => [0,2,4,6])
        Simp::TestHelpers.wait(30)
        on(agent, "puppet agent -t --ca_port 8141 --server #{master_fqdn}", :acceptable_exit_codes => [0,2,4,6])
        agent.reboot
        Simp::TestHelpers.wait(240)
        on(agent, "puppet agent -t --ca_port 8141 --server #{master_fqdn}", :acceptable_exit_codes => [0,2])
      end
      it 'should be idempotent' do
        Simp::TestHelpers.wait(30)
        on(agent, 'puppet agent -t', :acceptable_exit_codes => [0])
      end
    end
  end
end
