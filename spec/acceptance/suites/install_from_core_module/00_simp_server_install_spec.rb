require 'spec_helper_integration'
require 'beaker/puppet_install_helper'

test_name 'puppetserver module install via PuppetForge'

describe 'install puppetserver modules from PuppetForge' do

  masters = hosts_with_role(hosts, 'master')

  hosts.each do |host|
    it 'should set the root password' do
      on(host, "sed -i 's/enforce_for_root//g' /etc/pam.d/*")
      on(host, 'echo password | passwd root --stdin')
    end

    it 'should set up needed repositories' do
      host.install_package('epel-release')
      on(host, 'curl -s https://packagecloud.io/install/repositories/simp-project/6_X_Dependencies/script.rpm.sh | bash')
    end

    it 'should install git' do
      master.install_package('git')
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

      it 'should enable trusted_server_facts' do
        on(master, 'puppet config --section master set trusted_server_facts true')
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
      # move residual PKI files that will cause puppet module install to fail
      on(master, 'mv /etc/puppetlabs/code/environments/production/modules/pki /root/pki_backup')

      # install simp-simp_core and all its dependencies
      on(master, 'puppet module install /tmp/simp-simp_core*.tar.gz')

      # fix group and permissions of installed module files
      on(master, 'chown -R root.puppet /etc/puppetlabs/code/environments/production/modules')
      on(master, 'chmod -R g+rX /etc/puppetlabs/code/environments/production/modules')
    end
  end
end
