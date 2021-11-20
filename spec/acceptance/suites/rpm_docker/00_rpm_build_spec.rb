# Uses Beaker+Docker to package a full build of all SIMP packages for CentOS
#
# IF PACKAGES ARE MISSING, UPDATE THE DOCKERFILES IN simp-core AND RELEASE A NEW IMAGE
#
# Also works in Travis CI
#
# ## Building SIMP ISOs
#
# If you have a local 'ISO' directory in 'simp-core' with the necessary ISO
# images, this test will attempt to build a full SIMP ISO release.
#
# If you set the environment variable BEAKER_copyin=yes, it will copy in your
# local copy of the 'simp-core' repo instead of using the one on the
# filesystem. You probably want to also set BEAKER_destroy=no if you do this,
# so that you can retrieve any relevant artifacts.
#
#   * NOTE: This mode could be **MUCH** slower, but will preserve the state of
#           your workspace (including any local changes you may have made)
#
# ## Building RHEL ISOs
#
# This will also do a full build for RedHat in a vagrant box if the 'rhel7'
# nodeset is used.
#
# To make this work, copy only the redhat iso into the simp-core/ISO directory.
# In order to get the Redhat Build to work, you must set the following
# Environment variables:
#
#  BEAKER_RHSM_USER=(Your RedHat developer account name)
#  BEAKER_RHSM_PASS=(Your RedHat developer account password)
#  BEAKER_copyin=yes
#
# This will create the RedHat ISO and copy it out to simp-core directory.  If
# you need any of the other artifacts, set BEAKER_destroy=no and retrieve them
# from the VM.
#
# NOTE: BEAKER_copyin *MUST* be set to 'yes',  otherwise it will download
# simp-core from the simp repository and build the rpms from that, with the
# result that it will not create an ISO (even if you have an ISO directory)!
#
require 'spec_helper_rpm'

test_name 'RPM build'

# Set build directory inside the container
#
# The /simp-core mount will be mounted regardless of the test requirements so
# we have to use a different location if we want to copy things into the system
#
build_dir = ( ENV['BEAKER_copyin'] == 'yes' ) ? '/simp-import': '/simp-core'

def get_test_env
  test_env_variables = ENV.select { |env| env.match('^SIMP_') }
  env_string = ''
  test_env_variables.each do |key,value|
    next if key == 'SIMP_RPM_dist'

    env_string += "#{key}=#{value} "
  end

  return env_string
end

def docker_id(host)
  id = host[:docker_container_id]
  id = host[:docker_container].id if !id && host.host_hash.key?(:docker_container)

  return id
end

# Custom Gemfile Support
gemfile = nil
gemfile_path = File.expand_path(File.join(fixtures_path,'Gemfile'))

if File.file?(gemfile_path)
  gemfile = gemfile_path
end

describe 'RPM build' do
  local_basedir = File.absolute_path(Dir.pwd)

  # We need a normal user for building the RPMs
  let(:build_user) { 'build_user' }
  let(:run_cmd) { %(runuser #{build_user} -l -c ) }

  let(:iso_dir) { File.join(build_dir, 'ISO') }

  hosts.each do |host|
    let(:has_iso_dir?) { host.file_exist?(iso_dir) }

    next if host[:roles].include?('disabled')

    context 'when setting up the build' do
      # This needs to happen *prior* to the test selection since the test
      # selection depends on this being present
      if ENV['BEAKER_copyin'] == 'yes'
        if docker_id(host)
          %x(docker cp #{Dir.pwd} #{docker_id(host)}:#{build_dir})
        else
          copy_to(host, local_basedir, build_dir)
        end
      end

      it 'should clone the repo if necessary' do
        set_perms = false

        if ENV['BEAKER_copyin'] == 'yes'
          set_perms = true
        elsif !host.file_exist?("#{build_dir}/metadata.json")
          # Handle Travis CI first
          if ENV['TRAVIS_BUILD_DIR']
            base_dir = File.dirname(ENV['TRAVIS_BUILD_DIR'])

            if docker_id(host)
              %x(docker cp #{ENV['TRAVIS_BUILD_DIR']} #{docker_id(host)}:#{build_dir})
            else
              fail('Unable to copy files into container:  Cannot determine container ID from host_hash')
            end

            host.mkdir_p(base_dir)
            on(host, %(cd #{base_dir}; ln -s #{build_dir} .))
          else
            # Just clone the main simp repo
            on(host, %(git clone https://github.com/simp/simp-core #{build_dir}))
          end

          set_perms = true
        end

        if set_perms
          on(host, %(chown -R #{build_user}:#{build_user} #{build_dir}))
        end
      end

      it 'should have access to the local simp-core' do
        # This is to work around irritating artifacts left around by r10k
        unless local_basedir == build_dir
          host.mkdir_p(local_basedir)

          on(host, %(cd #{File.dirname(local_basedir)}; mount -o bind #{build_dir} #{File.basename(local_basedir)}))
        end

        host.file_exist?("#{local_basedir}/metadata.json")
      end

      it 'should align the build user uid and gid with the mounted filesystem' do
        on(host, %(if ! getent group `stat --printf="%g" #{build_dir}` >&/dev/null; then groupadd -g `stat --printf="%g" #{build_dir}` #{build_user}_supplementary; fi))

        on(host, %(usermod -u `stat --printf="%u" #{build_dir}` -G `stat --printf="%g" #{build_dir}` #{build_user}))

        on(host, %(chown -R #{build_user}:#{build_user} ~#{build_user}))
      end
    end

    context 'when running the build' do
      it 'should have the latest gems' do
        on(host, "#{run_cmd} 'cd #{local_basedir}; bundle update'")


        on(host, "#{run_cmd} 'cd #{local_basedir}; bundle config'")
        on(host, "#{run_cmd} 'cd #{local_basedir}; bundle exec gem env'")
        on(host, "#{run_cmd} 'cd #{local_basedir}; gem env'")
        on(host, "#{run_cmd} 'cd #{local_basedir}; bundle pristine'")
      end

      if fact_on(host, 'operatingsystem') == 'RedHat'
        it 'should copy the OS repos into the build directory' do
          osver = fact_on(host, 'operatingsystemmajrelease')

          # Copy the main OS repos into place for the build
          repo_dirs = on(host, "find #{build_dir}/build -name simp.repo").stdout.lines.grep(/RedHat\/#{osver}/).map(&:strip)
          repo_dirs.each do |repo_dir|
            on(host, "cp /etc/yum.repos.d/redhat*.repo #{File.dirname(repo_dir)}")
          end
        end
      end

      it 'should be able to build the ISO' do
        if has_iso_dir?
          on(host, "#{run_cmd} 'cd #{local_basedir}; SIMP_BUILD_docs=yes SIMP_BUILD_prompt=no #{get_test_env} bundle exec rake build:auto[ISO]'")
        else
          skip("No ISO dir present at #{iso_dir}")
        end
      end

      it 'should have all of the dependencies' do
        if has_iso_dir?
          skip('Built ISO')
        else
          on(host, "#{run_cmd} 'cd #{local_basedir}; bundle exec rake deps:checkout'")
        end
      end

      it 'should be able to build all modules ' do
        if has_iso_dir?
          skip('Built ISO')
        else
          on(host, "#{run_cmd} 'cd #{local_basedir}; #{get_test_env} bundle exec rake pkg:modules'")
        end
      end

      it 'should be able to build aux packages ' do
        if has_iso_dir?
          skip('Built ISO')
        else
          on(host, "#{run_cmd} 'cd #{local_basedir}; #{get_test_env} bundle exec rake pkg:aux'")
        end
      end
    end

    if ENV['BEAKER_copyin'] == 'yes'
      context 'when extracting the ISOs' do
        let(:isos) {
          on(host, %(find #{build_dir}/build -name "*.iso")).stdout
            .lines
            .map(&:strip)
            .delete_if{|x| x.empty?}
        }

        if docker_id(host)
          it 'should copy out the ISO files' do
            isos.each do |iso|
              %x(docker cp #{docker_id(host)}:#{build_dir} #{Dir.pwd})
            end
          end
        else
          it 'should copy out the resulting ISO files' do
            isos.each do |iso|
              scp_from(host, iso, local_basedir)
            end
          end
        end
      end
    end
  end
end
