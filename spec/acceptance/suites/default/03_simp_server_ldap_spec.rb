require 'spec_helper_integration'
require 'yaml'

test_name 'simp::server::ldap'

describe 'use the simp::server::ldap class to create and ldap environment' do
  masters = hosts_with_role(hosts, 'master')
  agents  = hosts_with_role(hosts, 'agent')

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

        hiera = YAML.load(on(master, 'cat /etc/puppetlabs/code/environments/production/hieradata/default.yaml').stdout)
        default_yaml = hiera.merge(
          'simp_options::ldap' => true,
          'simp_options::sssd' => true,
          'simp_openldap::server::conf::rootpw' => 's00persekr3t!',
          # 'simp_options::ldap::uri' => ['ldap://#{master_fqdn}']
        ).to_yaml
        create_remote_file(master, '/etc/puppetlabs/code/environments/production/manifests/site.pp', site_pp)
        create_remote_file(master, '/etc/puppetlabs/code/environments/production/hieradata/default.yaml', default_yaml)
      end
    end
  end

  context 'agents' do
    it 'set up and run puppet' do
      block_on(agents, :run_in_parallel => false) do |agent|
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
