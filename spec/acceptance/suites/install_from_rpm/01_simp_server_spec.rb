require 'spec_helper_rpm'
require 'erb'
require 'pathname'

test_name 'puppetserver via rpm'

describe 'install SIMP via rpm' do

  use_puppet_repo = ENV['BEAKER_puppet_repo'] || true

  masters = hosts_with_role(hosts, 'master')
  agents  = hosts_with_role(hosts, 'agent')
  let(:domain)      { fact_on(master, 'domain') }
  let(:master_fqdn) { fact_on(master, 'fqdn') }

  hosts.each do |host|
    it 'should set the root password' do
      on(host, "sed -i 's/enforce_for_root//g' /etc/pam.d/*")
      on(host, 'echo password | passwd root --stdin')
    end
    it 'should install the puppet repo' do
      if use_puppet_repo
        if host.host_hash[:platform] =~ /el-7/
          on(host, 'rpm -q puppetlabs-release-pc1 || yum install http://yum.puppetlabs.com/puppetlabs-release-pc1-el-7.noarch.rpm -y')
        else
          on(host, 'rpm -q puppetlabs-release-pc1 || yum install http://yum.puppetlabs.com/puppetlabs-release-pc1-el-6.noarch.rpm -y')
        end
      end
    end
  end

  context 'master' do
    let(:simp_conf_template) { File.read(File.open('spec/acceptance/common_files/simp_conf.yaml.erb')) }
    masters.each do |master|
      it 'should set up SIMP repositories' do
        master.install_package('epel-release')
        setup_repo(master)
        on(master, 'yum makecache')
      end

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

  context 'agents' do
    agents.each do |agent|
      it 'should install the agent' do
        agent.install_package('epel-release')
        agent.install_package('puppet-agent')
        agent.install_package('net-tools')
        setup_repo(agent)
      end

      it 'should configure the agent' do
        on(agent, "puppet config set server #{master_fqdn}")
        on(agent, 'puppet config set masterport 8140')
        on(agent, 'puppet config set ca_port 8141')
      end

      it 'should run the agent' do
        # Run puppet and expect changes
        retry_on(agent, 'puppet agent -t',
          :desired_exit_codes => [0,2],
          :retry_interval     => 15,
          :max_retries        => 5,
          :verbose            => true
        )

        agent.reboot
        # Wait for machine to come back up
        retry_on(agent, 'uptime', :retry_interval => 15 )

        retry_on(agent, '/opt/puppetlabs/bin/puppet agent -t',
          :desired_exit_codes => [0,2],
          :retry_interval     => 15,
          :max_retries        => 3,
          :verbose            => true
        )
      end
    end
  end
end
