require 'spec_helper_integration'
require 'beaker/puppet_install_helper'

test_name 'Install SIMP modules from Puppetforge and assets via r10k'

describe 'Install SIMP modules from Puppetforge and assets via r10k' do

  let(:production_env_dir) { '/etc/puppetlabs/code/environments/production' }
  let(:r10k) { '/opt/puppetlabs/puppet/bin/r10k' }

  context 'all hosts prep' do
    set_up_options = {
      :root_password => test_password(:root),
      :repos         => [
        :epel,
        :simp,      # TODO verify if this necessary
        :simp_deps,
        :puppet
      ]
    }

    hosts.each do |host|
      include_examples 'basic server setup', host, set_up_options
    end
  end

  # Use r10K to install the SIMP assets listed in Puppetfile.pinned into
  # a staging directory, and then manually install them where they would
  # have been installed by their corresponding RPMs.  This allows
  # us to use rubygem-simp-cli for creating the environment skeleton.
  context 'manual SIMP assets setup on puppetmaster' do

    master = only_host_with_role(hosts, 'master')
    assets_to_install = [
      :environment_skeleton, # simp-environment-skeleton
      :rsync_data,           # simp-rsync-skeleton
      :simp_selinux_policy,  # simp-selinux-policy
      :rubygem_simp_cli      # rubygem-simp-cli
    ]

    include_examples 'simp asset manual install', master, assets_to_install
  end

  # We'll use simp cli to create an environment skeleton
  context 'create the SIMP omni-environment skeleton' do
    # This has to be done **BEFORE** simp environment new is run
    # because the 'puppet' group needs to be defined
    it 'should install puppetserver' do
      install_puppetserver(master)
    end

    it 'should create a SIMP enviroment skeleton for the production env' do
      # remove the skeleton production environment installed by puppet-agent
      on(master, "rm -rf #{production_env_dir}")

      # use simp cli to correctly create SIMP omni environment skeleton without
      # a Puppetfile
      on(master, 'simp environment new production --no-puppetfile-gen')
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
      on(master, 'simp environment fix production --no-secondary-env --no-writable-env')
    end
  end
end
