# assets_to_install: array of assets to install; valid values are
#              :environment_skeleton - simp-environment-skeleton
#              :rsync_data           - simp-rsync-skeleton
#              :simp_selinux_policy  - simp-selinux-policy
#              :rubygem_simp_cli     - rubygem-simp-cli
#              :simp_utils           - simp-utils
#
# FIXME: This code ASSUMES specific 'module' names used for assets in
#        simp-core Puppetfiles.
shared_examples 'simp asset manual install' do |server, assets_to_install|

  context 'asset staging using r10k' do
    it "should install git RPM, rsync RPM and r10k gem into Puppet's Ruby" do
      # NOTE:
      # - puppet-agent has already been installed during the basic server
      #   setup
      # - r10k gem needs git, but unlike the simp-vendored-r10k RPM, has
      #   no mechanism to ensure git gets installed
      # - simp-adapter needs git and rsync
      install_package_unless_present_on(server, 'git')
      install_package_unless_present_on(server, 'rsync')

      on(server, 'puppet resource package r10k ensure=present provider=puppet_gem')
    end

    it 'should create a Puppetfile for assets from Puppetfile.pinned' do
      file_content = create_r10k_puppetfile('Puppetfile.pinned', 'src/assets')
      create_remote_file(server, '/root/Puppetfile.assets', file_content)
    end

    it "should clone SIMP's assets into a staging dir using r10k" do
      # retry to work around intermittent connectivity issues
      retry_on(server,
        "#{r10k} puppetfile install -v info --moduledir=/root/assets --puppetfile=/root/Puppetfile.assets",
        :desired_exit_codes => [0],
        :retry_interval     => 15,
        :max_retries        => 3,
        :verbose            => true.to_s  # work around beaker bug
      )
    end
  end

  unless assets_to_install.empty?
    context 'asset installation from local git clones' do
      let(:skeleton_dir) { '/usr/share/simp/environment-skeleton' }

      if assets_to_install.include?(:environment_skeleton)
        it 'should install simp-environment-skeleton as done by its RPM' do
          on(server, "mkdir -p #{skeleton_dir}")
          on(server, "cp -r /root/assets/environment/environments/puppet #{skeleton_dir}")
          on(server, "cp -r /root/assets/environment/environments/secondary #{skeleton_dir}")
          on(server, "mkdir -p #{skeleton_dir}/writable/simp_autofiles")
          on(server, "mkdir -p #{skeleton_dir}/secondary/site_files/krb5_files/files/keytabs")
          on(server, "mkdir -p #{skeleton_dir}/secondary/site_files/pki_files/files/keydist/cacerts")
          on(server, "cp -r /root/assets/environment/environments/secondary #{skeleton_dir}")
          on(server, "chmod -R g+rX,o-rwx #{skeleton_dir}")
        end
      end

      if assets_to_install.include?(:rsync_data)
        it 'should install simp-rsync-skeleton as done by its RPM' do
          on(server, "mkdir -p #{skeleton_dir}")
          on(server, "cp -r /root/assets/rsync_data/rsync #{skeleton_dir}")
          on(server, "chmod -R g+rX,o-rwx #{skeleton_dir}/rsync")
        end
      end

      if assets_to_install.include?(:simp_selinux_policy)
        it "should build SIMP's selinux contexts as done by simp-selinux-policy RPM" do
          server.install_package('yum-utils')
          # NOTE:
          # - For this test, we don't need to revert to the original versions
          #   of the selinux build dependencies for the major OS version. We
          #   bypass the version downgrades using SIMP_ENV_NO_SELINUX_DEPS=yes.
          # - yum-builddep temporarily enables all repos to do its work.
          #   Unfortunately, the puppetXXX-source repo isn't set up correctly
          #   and the easiest way to exclude this repo during this command
          #   is to add the --disablerepo=puppetXXX option. (For some odd
          #   reason --disablerepo=puppetXXX-source didn't work...)
          puppet_repo = ENV['BEAKER_PUPPET_COLLECTION'] || 'puppet6'
          yum_cmd = [
            'SIMP_ENV_NO_SELINUX_DEPS=yes',
            'yum-builddep -y',
            '/root/assets/simp_selinux_policy/build/simp-selinux-policy.spec',
            "--disablerepo=#{puppet_repo}"
          ].join(' ')
          on(server, yum_cmd)

          build_command = [
            'cd /root/assets/simp_selinux_policy/build/selinux',
            'make -f /usr/share/selinux/devel/Makefile'
          ].join('; ')
          on(server, build_command)
        end

        it "should install SIMP's selinux contexts as done by simp-selinux-policy RPM" do
          file_install_cmd = [
            'install -p -m 644 -D',
            '/root/assets/simp_selinux_policy/build/selinux/simp.pp',
            '/usr/share/selinux/packages/simp.pp'
          ].join(' ')
          on(server, file_install_cmd)
          on(server, '/root/assets/simp_selinux_policy/sbin/set_simp_selinux_policy install')
        end
      end

      if assets_to_install.include?(:rubygem_simp_cli)
        # We have to install the simp-cli gem and its dependent highline gem
        # in the same gem path to ensure the `simp` command uses the version of
        # highline it was tested with, **not** the version of highline bundled
        # with puppet-agent!
        it 'should package simp-cli and highline gems' do
          cmd = 'cd /root/assets/rubygem_simp_cli; ' +
                '/opt/puppetlabs/puppet/bin/gem build simp-cli.gemspec'
          on(server, cmd)

          cmd = 'cd /root/assets/rubygem_simp_cli/ext/gems/highline; ' +
                '/opt/puppetlabs/puppet/bin/gem build highline.gemspec'
          on(server, cmd)
        end

        it 'should install simp-cli and highline gems in /usr/share/simp/ruby' do
          gemdir = '/usr/share/simp/ruby'
          on(server, "mkdir -p #{gemdir}")
          cmd_prefix = [
            '/opt/puppetlabs/puppet/bin/gem',
            'install',
            '--local',
            "--install-dir #{gemdir}",
            '--force'
          ].join(' ')
          on(server, "#{cmd_prefix} /root/assets/rubygem_simp_cli/simp-cli*.gem")
          on(server, "#{cmd_prefix} /root/assets/rubygem_simp_cli/ext/gems/highline/highline*.gem")
        end

        it "should install 'simp' script similar to that done by the rubygem-simp-cli RPM" do
          simp_script = <<~EOM
            #!/bin/bash

            PATH=/opt/puppetlabs/bin:/opt/puppetlabs/puppet/bin:$PATH

            /usr/share/simp/ruby/gems/simp-cli-*/bin/simp $@

          EOM

          create_remote_file(server, '/bin/simp', simp_script)
          on(server, 'chmod +x /bin/simp')
        end
      end

      if assets_to_install.include?(:simp_utils)
        it 'installs simp_utils' do
          on(server, 'cp -r /root/assets/utils/scripts/* /usr/local')
          on(server, 'chmod -R go+rX /usr/local')
        end
      end
    end
  end
end
