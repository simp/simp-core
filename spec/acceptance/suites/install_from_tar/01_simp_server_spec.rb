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
    let(:simp_conf_template) { File.read(File.open('spec/acceptance/common_files/simp_conf.yaml.erb')) }
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
        if agent.host_hash[:platform] =~ /el-7/
          agent.install_package('http://yum.puppetlabs.com/puppetlabs-release-pc1-el-7.noarch.rpm')
        else
          agent.install_package('http://yum.puppetlabs.com/puppetlabs-release-pc1-el-6.noarch.rpm')
        end
      end

      #Set up the simp project dependency repo
      internet_deprepo(master)

      it 'should install simp' do
        master.install_package('simp-adapter-foss')
        master.install_package('simp')
      end

      it 'should run simp config' do
        create_remote_file(master, '/root/simp_conf.yaml', ERB.new(simp_conf_template).result(binding))
        cmd = [
          'simp config',
          '-a /root/simp_conf.yaml',
          # '--quiet',
          # '--skip-safety-save',
          'grub::password=s00persekr3t%',
          'simp_openldap::server::conf::rootpw=s00persekr3t%'
        ].join(' ')
        on(master, cmd)
      end

      it 'should provide default hieradata to make beaker happy' do
        beaker_hiera = YAML.load(File.read('spec/acceptance/common_files/beaker_hiera.yaml'))
        hiera        = beaker_hiera.merge( 'simp::rsync_stunnel' => master_fqdn )

        create_remote_file(master, '/etc/puppetlabs/code/environments/simp/hieradata/default.yaml', hiera.to_yaml)
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

      it 'should settle after reboot' do
        on(master, '/opt/puppetlabs/bin/puppet agent -t', :acceptable_exit_codes => [0,2,4,6])
      end
      it 'should have puppet runs with no changes' do
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
        sleep(30)
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
