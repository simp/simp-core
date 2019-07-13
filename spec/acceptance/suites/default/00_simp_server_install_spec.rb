require 'spec_helper_integration'

test_name 'Install SIMP modules and assets via r10K'

describe 'Install SIMP modules and assets via r10K' do

  let(:production_env_dir) { '/etc/puppetlabs/code/environments/production' }
  let(:r10k) { '/opt/puppetlabs/puppet/bin/r10k' }

  context 'all hosts prep' do
    set_up_options = {
      :root_password => test_password,
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

  # We'll use simp cli to create an environment skeleton and then
  # populate the modules directory from a Puppetfile derived from
  # Puppetfile.pinned
  context 'pre-populate SIMP omni-environment' do
    # This has to be done **BEFORE** simp environment new is run
    # because the 'puppet' group needs to be defined
    it 'should install puppetserver' do
      master.install_package('puppetserver')
    end

    it 'should create a SIMP enviroment skeleton for the production env' do
      # remove the skeleton production environment installed by puppet-agent
      on(master, "rm -rf #{production_env_dir}")

      # use simp cli to correctly create SIMP omni environment skeleton without
      # a Puppetfile
      on(master, 'simp environment new production --no-puppetfile-gen')
    end

    it 'should create a Puppetfile in production env from Puppetfile.pinned' do
      file_content = create_r10k_puppetfile('Puppetfile.pinned', 'src/puppet/modules')
      create_remote_file(master, "#{production_env_dir}/Puppetfile", file_content)
    end

    it 'should deploy the modules using the Puppetfile' do
      # retry to work around intermittent connectivity issues
      retry_on(master,
        "cd #{production_env_dir}; #{r10k} puppetfile install -v info",
        :desired_exit_codes => [0],
        :retry_interval     => 15,
        :max_retries        => 3,
        :verbose            => true.to_s  # work around beaker bug
      )

      # fix group and permissions of installed module files
      on(master, 'simp environment fix production --no-secondary-env --no-writable-env')
    end
  end
end
