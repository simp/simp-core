require 'spec_helper_integration'
require 'beaker/puppet_install_helper'

# Create a Puppetfile for R10K from module
# portion of a simp-core Puppetfile.<tracking|stable>.
# Returns Puppetfile content
def create_r10k_puppetfile(simp_core_puppetfile)
  r10k_puppetfile = []
  lines = IO.readlines(simp_core_puppetfile)
  modules_section = false
  lines.each do |line|
     if line.match(/^moduledir/)
       if line.match(/^moduledir 'src\/puppet\/modules'/)
         modules_section = true
       else
         modules_section = false
       end
       next
     end
     r10k_puppetfile << line if modules_section
  end
  r10k_puppetfile.join  # each line already contains a \n
end

test_name 'puppetserver via r10k'

describe 'install environment via r10k and puppetserver' do

  context 'all hosts prep' do
    it 'should install repos and set root pw' do
      block_on(hosts, :run_in_parallel => false) do |host|
        # set the root password
        on(host, "sed -i 's/enforce_for_root//g' /etc/pam.d/*")
        on(host, 'echo password | passwd root --stdin')
        # set up needed repositories
        host.install_package('epel-release')

        template = File.read('spec/acceptance/suites/default/files/6_X_Dependencies.repo')
        repo     = template.gsub(/%RELEASEVER%/, fact_on(host,'operatingsystemmajrelease'))
        create_remote_file(host, '/etc/yum.repos.d/simp-project_6_X_Dependencies.repo', repo)
      end
    end
  end

  context 'install and start a standard puppetserver' do
    it 'should install puppetserver' do
      master.install_package('puppetserver')
    end

    it 'install the r10k gem' do
      master.install_package('git')
      on(master, 'puppet resource package r10k ensure=present provider=puppet_gem')
    end

    it 'should start puppetserver' do
      on(master, 'puppet resource service puppetserver ensure=running')
    end

    it 'should do some misc configuration' do
      p_version = on(hosts.first,'puppet --version').stdout.strip
      if Gem::Version.new(p_version) >= Gem::Version.new('5')
        on(master, 'puppet config --section master set trusted_server_facts true')
      end

      # update packages so we can use TLS1.2 to connect to github
      if master.host_hash[:box] =~ /oel/ and master.host_hash[:platform] =~ /el-6/
        on(master,'yum upgrade -y git curl openssl nss')
      end
    end
  end

  context 'install modules via r10k' do
    it 'should create a Puppetfile in $codedir from Puppetfile.tracking' do
      file_content = create_r10k_puppetfile('Puppetfile.tracking')
      create_remote_file(master, '/etc/puppetlabs/code/environments/production/Puppetfile',
        file_content)
    end

    it 'should install the Puppetfile' do
      on(master, 'cd /etc/puppetlabs/code/environments/production; /opt/puppetlabs/puppet/bin/r10k puppetfile install', :accept_all_exit_codes => true)
      on(master, 'cd /etc/puppetlabs/code/environments/production; /opt/puppetlabs/puppet/bin/r10k puppetfile install')
      on(master, 'chown -R root.puppet /etc/puppetlabs/code/environments/production/modules')
      on(master, 'chmod -R g+rX /etc/puppetlabs/code/environments/production/modules')
    end
  end
end
