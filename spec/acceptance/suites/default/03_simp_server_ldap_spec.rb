require 'spec_helper_integration'
require 'yaml'

test_name 'simp::server::ldap'

describe 'use the simp::server::ldap class to create and ldap environment' do
  masters     = hosts_with_role(hosts, 'master')
  agents      = hosts_with_role(hosts, 'agent')
  # master_fqdn = fact_on(master, 'fqdn')

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

        hiera = YAML.load(on(master, 'cat /etc/puppetlabs/code/environments/production/hieradata/default.yaml'))
        default_yaml = hiera.merge(
          'simp_options::ldap' => true,
          'simp_options::sssd' => true,
          'simp_openldap::server::conf::rootpw' => 's00persekr3t!',
          # 'simp_options::ldap::uri' => ['ldap://#{master_fqdn}']
        )
        create_remote_file(master, '/etc/puppetlabs/code/environments/production/manifests/site.pp', site_pp)
        create_remote_file(master, '/etc/puppetlabs/code/environments/production/hieradata/default.yaml', default_yaml.to_yaml)
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
