require 'spec_helper_integration'
require 'beaker/puppet_install_helper'

test_name 'puppetserver module install via PuppetForge'

describe 'install puppetserver modules from PuppetForge' do

  masters = hosts_with_role(hosts, 'master')

  context 'all hosts prep' do
    it "should set passwords and install packages/repositories" do
      block_on(hosts, :run_in_parallel => false) do |host|
        # set the root password
        on(host, "sed -i 's/enforce_for_root//g' /etc/pam.d/*")
        on(host, 'echo password | passwd root --stdin')
        # set up needed repositories
        host.install_package('epel-release')
      end
    end
  end

  context 'install and start a standard puppetserver' do
    masters.each do |master|
      it 'should install puppetserver' do
        master.install_package('puppetserver')
      end

      it 'should start puppetserver' do
        on(master, 'puppet resource service puppetserver ensure=running')
      end
    end
  end

  context 'install modules via simp-simp_core meta module' do
    it 'should create simp-simp_core module' do
      FileUtils.rm_rf('pkg')
      puts `puppet module build`
      result = $?
      unless result.nil?
        expect(result.exitstatus).to eq 0
      end
      files = Dir.glob('pkg/simp-simp_core*.tar.gz')
      expect(files.size).to eq 1
      module_tar = files[0]
      scp_to(master, module_tar, '/tmp')
    end

    it 'should install the module' do
      # install simp-simp_core and all its dependencies
      on(master, 'puppet module install /tmp/simp-simp_core*.tar.gz')

      # fix group and permissions of installed module files
      on(master, 'chown -R root.puppet /etc/puppetlabs/code/environments/production/modules')
      on(master, 'chmod -R g+rX /etc/puppetlabs/code/environments/production/modules')
    end
  end
end
