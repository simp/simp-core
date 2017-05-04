require 'spec_helper_rpm'
require 'erb'
require 'pathname'

test_name 'puppetserver via rpm'

# Find a release tarball
def find_tarball
  tarball = ENV['BEAKER_release_tarball']
  tarball ||= Dir.glob('build/distributions/CentOS/7/x86_64/DVD_Overlay/SIMP*.tar.gz')[0]
  warn("Found Tarball: #{tarball}")
  tarball
end

def find_reponame
  reponame = ENV['BEAKER_reponame']
  reponame ||= '6_X'
  warn("Using SIMP reponame #{reponame}")
  reponame
end

def tarball_yumrepos(host, tarball)
  if tarball =~ /download/
    filename = 'SIMP-6.0.0-0-CentOS-7-x86_64.tar.gz'
    url = "https://simp-project.com/ISO/SIMP/tar_bundles/#{filename}"
    require 'net/http'
    File.write("spec/fixtures/#{filename}", Net::HTTP.get(URI.parse(url)))
    tarball = Dir.glob('spec/fixtures/SIMP*.tar.gz')[0]
  end

  warn('='*72)
  warn("Found Tarball: #{tarball}")
  warn('Test will continue by setting up a local repository on the master from the tarball')
  warn('='*72)

  host.install_package('http://yum.puppetlabs.com/puppetlabs-release-pc1-el-7.noarch.rpm')
  on(host, "curl -s https://packagecloud.io/install/repositories/simp-project/6_X_Dependencies/script.rpm.sh | bash")

  host.install_package('createrepo')
  scp_to(host, tarball, '/root/')
  tarball_basename = File.basename(tarball)
  on(host, "mkdir -p /var/www && cd /var/www && tar xzf /root/#{tarball_basename}")
  on(host, 'createrepo -q -p /var/www/SIMP/noarch')
  create_remote_file(host, '/etc/yum.repos.d/simp_tarball.repo', <<-EOF.gsub(/^\s+/,'')
    [simp-tarball]
    name=Tarball repo
    baseurl=file:///var/www/SIMP/noarch
    enabled=1
    gpgcheck=0
    repo_gpgcheck=0
    EOF
  )
  on(host, 'yum makecache')
end

# Install the packagecloud yum repos
# See https://packagecloud.io/simp-project/ for the reponame key
def internet_yumrepos(host, reponame)
  if reponame !~ /manual/
    warn('='*72)
    warn('Using Internet repos from packagecloud for testing')
    warn('Specify a tarball with BEAKER_release_tarball or by placing one in spec/fixtures')
    warn('='*72)

    on(host, "curl -s https://packagecloud.io/install/repositories/simp-project/#{reponame}/script.rpm.sh | bash")
    on(host, "curl -s https://packagecloud.io/install/repositories/simp-project/#{reponame}_Dependencies/script.rpm.sh | bash")
  else
    warn('Internet yumrepos disabled, modify nodeset to add manual repos')
  end
end


describe 'install SIMP via rpm' do

  masters = hosts_with_role(hosts, 'master')
  agents  = hosts_with_role(hosts, 'agent')
  let(:domain)      { fact_on(master, 'domain') }
  let(:master_fqdn) { fact_on(master, 'fqdn') }

  hosts.each do |host|
    it 'should set the root password' do
      on(host, "sed -i 's/enforce_for_root//g' /etc/pam.d/*")
      on(host, 'echo password | passwd root --stdin')
    end
  end

  context 'master' do
    let(:simp_conf_template) { File.read(File.open('spec/acceptance/suites/rpm_el7/files/simp_conf.yaml.erb')) }
    masters.each do |master|
      it 'should set up SIMP repositories' do
        master.install_package('epel-release')

        tarball = find_tarball
        if tarball.nil? or tarball.empty?
          internet_yumrepos(master, find_reponame)
        else
          tarball_yumrepos(master, tarball)
        end
        on(master, 'yum makecache')
      end

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
        if agent.host_hash[:platform] =~ /el-7/
          agent.install_package('http://yum.puppetlabs.com/puppetlabs-release-pc1-el-7.noarch.rpm')
        else
          agent.install_package('http://yum.puppetlabs.com/puppetlabs-release-pc1-el-6.noarch.rpm')
          # the portreserve service will fail unless something is configured
          on(agent, 'mkdir -p /etc/portreserve')
          on(agent, 'echo rndc/tcp > /etc/portreserve/named')
        end
        agent.install_package('puppet-agent')
        agent.install_package('net-tools')
        internet_yumrepos(agent, find_reponame)
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
