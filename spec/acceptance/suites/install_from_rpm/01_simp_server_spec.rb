require 'spec_helper_rpm'
require 'erb'
require 'pathname'

test_name 'puppetserver via rpm'

describe 'install SIMP via rpm' do

  use_puppet_repo = ENV['BEAKER_puppet_repo'] || true

  masters     = hosts_with_role(hosts, 'master')
  agents      = hosts_with_role(hosts, 'agent')
  syslog_servers = []  # needed for simp_conf.yaml template
  domain      = fact_on(master, 'domain')
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

  # needed for simp_conf.yaml template
  let(:trusted_nets) do
    require 'json'
    require 'ipaddr'
    networking = JSON.load(on(master, 'facter --json networking').stdout)
    networking['networking']['interfaces'].delete_if { |key,value| key == 'lo' }
    trusted_nets = networking['networking']['interfaces'].map do |key,value|
      net_mask = IPAddr.new(value['netmask']).to_i.to_s(2).count("1")
      "#{value['network']}/#{net_mask}"
    end
  end

  context 'all hosts prep' do
    it 'should install repos and set root pw' do
      block_on(hosts, :run_in_parallel => false) do |host|
        # set the root password
        on(host, "sed -i 's/enforce_for_root//g' /etc/pam.d/*")
        on(host, 'echo password | passwd root --stdin')
        # set up needed repositories
        if use_puppet_repo
          if host.host_hash[:platform] =~ /el-7/
            on(host, 'rpm -q puppetlabs-release-pc1 || yum install http://yum.puppetlabs.com/puppetlabs-release-pc1-el-7.noarch.rpm -y')
          else
            on(host, 'rpm -q puppetlabs-release-pc1 || yum install http://yum.puppetlabs.com/puppetlabs-release-pc1-el-6.noarch.rpm -y')
          end
        end
      end
    end
  end

  context 'master' do
    let(:simp_conf_template) { File.read('spec/acceptance/common_files/simp_conf.yaml.erb') }
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
          '-a /root/simp_conf.yaml'
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
        # Remove the lock file because we've already added the vagrant user
        # access and won't be locked out of the VM
        on(master, 'rm -f /root/.simp/simp_bootstrap_start_lock')
        on(master, 'simp bootstrap --no-verbose -u --remove_ssldir > /dev/null')
      end

      it 'should reboot the master' do
        master.reboot
        retry_on(master, puppetserver_status_cmd, :retry_interval => 10)
      end

      it 'should settle after reboot' do
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

      it 'should mock freshclam' do
        master.install_package('clamav-update')
        ## # Uncomment to use real FreshClam data from the internet
        ## create_remote_file(master, '/tmp/freshclam.conf', <<-EOF.gsub(/^\s+/,'')
        ##     DatabaseDirectory /var/simp/environments/production/rsync/Global/clamav
        ##     DatabaseMirror database.clamav.net
        ##     Bytecode yes
        ##   EOF
        ## )
        ## on(master, 'freshclam -u root --config-file=/tmp/freshclam.conf')
        ## on(master, 'chown clam.clam /var/simp/environments/production/rsync/Global/clamav/*')
        ## on(master, 'chmod u=rw,g=rw,o=r /var/simp/environments/production/rsync/Global/clamav/*')

        # Mock ClamAV data by just `touch`ing the data files
        on(master, 'touch /var/simp/environments/production/rsync/Global/clamav/{daily,bytecode,main}.cvd')
      end
    end
  end

  context 'agents' do
    it 'set up and run puppet' do
      block_on(agents, :run_in_parallel => false) do |agent|
        agent.install_package('epel-release')
        agent.install_package('puppet-agent')
        agent.install_package('net-tools')
        setup_repo(agent)

        on(agent, "puppet config set server #{master_fqdn}")
        on(agent, 'puppet config set masterport 8140')
        on(agent, 'puppet config set ca_port 8141')

        # Run puppet and expect changes
        retry_on(agent, '/opt/puppetlabs/bin/puppet agent -t',
          :desired_exit_codes => [0,2],
          :retry_interval     => 15,
          :max_retries        => 5,
          :verbose            => true
        )

        # Wait for machine to come back up
        agent.reboot
        retry_on(master, puppetserver_status_cmd, :retry_interval => 10)
        retry_on(agent, 'uptime', :retry_interval => 15 )

        # Wait for things to settle and stop making changes
        retry_on(agent, '/opt/puppetlabs/bin/puppet agent -t',
          :desired_exit_codes => [0],
          :retry_interval     => 15,
          :max_retries        => 3,
          :verbose            => true
        )
      end
    end
  end
end
