# This test attempts to set up two repos,
# 1) the simp repo which contains all the puppet modules for a simp deployment
# 2) the dependancy repo that contains rpm used by simp.
#
# Use the following ENV variables to configure the test:
#
# BEAKER_repo
#     This is used by 'cloud' set up to determine which package cloud
#     repos to use to set up the dependancies repo.  It defaults to 6_X.
#
# BEAKER_release_tarball
#     This can be used to override the simp libraries with either cloud or default.
#     It should be either
#        - a url pointing to a tar ball to be downloaded (http: or https:).
#        - a full path to a tarball located on the server running the tests.
#     default:  in it is not set it will look for the tar ball in the DVD_Overlay
#     directory under the simp-core/build directory.
#
require 'spec_helper_tar'
require 'erb'
require 'pathname'

test_name 'puppetserver via tarball'

describe 'install SIMP via tarball' do

  masters = hosts_with_role(hosts, 'master')
  agents  = hosts_with_role(hosts, 'agent')
  let(:domain)      { fact_on(master, 'domain') }
  let(:master_fqdn) { fact_on(master, 'fqdn') }
  let(:majver)      { fact_on(master, 'operatingsystemmajrelease') }
  let(:osname)      { fact_on(master, 'operatingsystem') }

  hosts.each do |host|
    it 'should set the root password' do
      on(host, "sed -i 's/enforce_for_root//g' /etc/pam.d/*")
      on(host, 'echo password | passwd root --stdin')
    end
  end

  context 'master' do
    let(:simp_conf_template) { File.read(File.open('spec/acceptance/suites/tar_el7/files/simp_conf.yaml.erb')) }
    masters.each do |master|
      it 'should set up SIMP repositories' do
        master.install_package('epel-release')

        tarball = find_tarball(majver, osname)
        if tarball.nil?
          fail("Tarball not found")
        else
          tarball_yumrepos(master, tarball)
        end
        on(master, 'yum makecache')
      end

      use_puppet_repo = ENV['BEAKER_puppet_repo'] || false
      if use_puppet_repo
        master.install_package('http://yum.puppetlabs.com/puppetlabs-release-pc1-el-7.noarch.rpm')
      end

      #Set up the simp project dependancy repo
      internet_deprepo(master)

      it 'should install simp' do
        master.install_package('simp-adapter-foss')
        master.install_package('simp')
      end

      it 'should run simp config' do
        # grub password: H.SxdcuyF56G75*3ww*HF#9i-eDM3Dp5
        # ldap root password: Q*AsdtFlHSLp%Q3tsSEc3vFbFx5Vwe58
        create_remote_file(master, '/root/simp_conf.yaml', ERB.new(simp_conf_template).result(binding))
        on(master, 'simp config -a /root/simp_conf.yaml --quiet --skip-safety-save')
      end

      it 'should provide default hieradata to make beaker happy' do
        create_remote_file(master, '/etc/puppetlabs/code/environments/simp/hieradata/default.yaml', {
          'sudo::user_specifications' => {
            'vagrant_all' => {
              'user_list' =>  ['vagrant'],
              'cmnd'      =>  ['ALL'],
              'passwd'    =>  false,
            },
          },
          'pam::access::users' => {
            'defaults' => {
              'origins'    => ['ALL'],
              'permission' =>  '+'
            },
            'vagrant' => nil
          },
          'ssh::server::conf::permitrootlogin'    =>  true,
          'ssh::server::conf::authorizedkeysfile' =>  '.ssh/authorized_keys',
          # The following settings are because $server_facts['serverip'] is
          # incorrect in a beaker/vagrant (mutli-interface) environment
          'simp::puppet_server_hosts_entry'       => false,
          'simp::rsync_stunnel'                   => master_fqdn,
          # Make sure puppet doesn't run (hopefully)
          'pupmod::agent::cron::minute'           => '0',
          'pupmod::agent::cron::hour'             => '0',
          'pupmod::agent::cron::weekday'          => '0',
          'pupmod::agent::cron::month'            => '1',
          }.to_yaml
        )
      end
      it 'should enable autosign' do
        on(master, 'puppet config --section master set autosign true')
      end

      it 'should run simp bootstrap' do
        # Remove the lock file because we've already added the vagrant user stuff
        on(master, 'rm -f /root/.simp/simp_bootstrap_start_lock')

        on(master, 'simp bootstrap --no-verbose -u --remove_ssldir > /dev/null')
      end

      it 'should reboot the host' do
        master.reboot
        sleep(240)
      end
      it 'should have puppet runs with no changes' do
        on(master, '/opt/puppetlabs/bin/puppet agent -t', :acceptable_exit_codes => [0,2,4,6])
        on(master, '/opt/puppetlabs/bin/puppet agent -t', :acceptable_exit_codes => [0] )
      end
      it 'should generate agent certs' do
        togen = []
        agents.each do |agent|
          togen << agent.hostname + '.' + domain
        end
        create_remote_file(master, '/var/simp/environments/production/FakeCA/togen', togen.join("\n"))
        on(master, 'cd /var/simp/environments/production/FakeCA; ./gencerts_nopass.sh')
      end
    end
  end

  # context 'classify nodes' do
  # end

  context 'agents' do
    agents.each do |agent|
      it 'should install the agent' do
        use_puppet_repo = ENV['BEAKER_puppet_repo'] || false
        if use_puppet_repo
          if agent.host_hash[:platform] =~ /el-7/
            agent.install_package('http://yum.puppetlabs.com/puppetlabs-release-pc1-el-7.noarch.rpm')
          else
            agent.install_package('http://yum.puppetlabs.com/puppetlabs-release-pc1-el-6.noarch.rpm')
            # the portreserve service will fail unless something is configured
            on(agent, 'mkdir -p /etc/portreserve')
            on(agent, 'echo rndc/tcp > /etc/portreserve/named')
          end
        end
        internet_deprepo(agent)
        agent.install_package('epel-release')
        agent.install_package('puppet-agent')
        agent.install_package('net-tools')
        internet_deprepo(agent)
      end
      it 'should run the agent' do
        # require 'pry';binding.pry if fact_on(agent, 'hostname') == 'agent'
        on(agent, "/opt/puppetlabs/bin/puppet agent -t --ca_port 8141 --masterport 8140 --server #{master_fqdn}", :acceptable_exit_codes => [0,2,4,6])
        on(agent, '/opt/puppetlabs/bin/puppet agent -t', :acceptable_exit_codes => [0,2,4,6])
        agent.reboot
        sleep(240)
        on(agent, '/opt/puppetlabs/bin/puppet agent -t', :acceptable_exit_codes => [0,2])
      end
      it 'should be idempotent' do
        sleep(30)
        on(agent, '/opt/puppetlabs/bin/puppet agent -t', :acceptable_exit_codes => [0])
      end
    end
  end

end
