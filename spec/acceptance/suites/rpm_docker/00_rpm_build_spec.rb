# Uses Docker to do a full build of all SIMP packages
#
# Also works in Travis CI
#
# If you have a local 'ISO' directory in 'simp-core' with the necessary ISO
# images, will attempt to build a full SIMP ISO release.
#
# If you set the environment variable BEAKER_copyin=yes will copy in your
# 'simp-core' repo instead of using the one on the filesystem. You probably
# want to also set BEAKER_destroy=no if you do this so that you can retrieve
# any relevant artifacts.
#
#   * This mode could be **MUCH** slower but will preserve the sanctity of your
#     workspace
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

      unless docker_id(host)
        it 'should install the basic utils' do
          host.install_package('yum-utils')
          host.install_package('git')
          host.install_package('selinux-policy-targeted')
          host.install_package('selinux-policy-devel')
          host.install_package('policycoreutils')
          host.install_package('policycoreutils-python')
        end

        it 'should install EPEL' do
          host.install_package('epel-release')
        end

        it 'should install the build utils' do
          host.install_package('openssl')
          host.install_package('util-linux')
          host.install_package('rpm-build')
          host.install_package('augeas-devel')
          host.install_package('createrepo')
          host.install_package('genisoimage')
          host.install_package('git')
          host.install_package('gnupg2')
          host.install_package('libicu-devel')
          host.install_package('libxml2')
          host.install_package('libxml2-devel')
          host.install_package('libxslt')
          host.install_package('libxslt-devel')
          host.install_package('rpmdevtools')
          host.install_package('which')
          host.install_package('ruby-devel')
          host.install_package('rpm-devel')
          host.install_package('rpm-sign')
        end

        it 'should install RVM deps' do
          host.install_package('libyaml-devel')
          host.install_package('glibc-headers')
          host.install_package('autoconf')
          host.install_package('gcc')
          host.install_package('gcc-c++')
          host.install_package('glibc-devel')
          host.install_package('readline-devel')
          host.install_package('libffi-devel')
          host.install_package('automake')
          host.install_package('libtool')
          host.install_package('bison')
          host.install_package('sqlite-devel')
        end

        it 'should set up the build user' do
          on(host, %(echo 'Defaults:build_user !requiretty' >> /etc/sudoers))
          on(host, %(echo 'build_user ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers))
          on(host, %(useradd -b /home -G wheel -m -c "Build User" -s /bin/bash -U build_user))
          on(host, %(rm -rf /etc/security/limits.d/*.conf))

          on(host, %(#{run_cmd} "for i in {1..5}; do { gpg2 --keyserver  hkp://pool.sks-keyservers.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 || gpg2 --keyserver hkp://pgp.mit.edu --recv-key 409B6B1796C275462A1703113804BB82D39DC0E3 || gpg2 --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3; } && break || sleep 1; done"))
          on(host, %(#{run_cmd} "for i in {1..5}; do { gpg2 --keyserver  hkp://pool.sks-keyservers.net --recv-keys 7D2BAF1CF37B13E2069D6956105BD0E739499BDB || gpg2 --keyserver hkp://pgp.mit.edu --recv-keys 7D2BAF1CF37B13E2069D6956105BD0E739499BDB || gpg2 --keyserver hkp://keys.gnupg.net --recv-keys 7D2BAF1CF37B13E2069D6956105BD0E739499BDB; } && break || sleep 1; done"))
          on(host, %(#{run_cmd} "gpg2 --refresh-keys"))
          on(host, %(#{run_cmd} "curl -sSL https://raw.githubusercontent.com/rvm/rvm/stable/binscripts/rvm-installer -o rvm-installer && curl -sSL https://raw.githubusercontent.com/rvm/rvm/stable/binscripts/rvm-installer.asc -o rvm-installer.asc && gpg2 --verify rvm-installer.asc rvm-installer && bash rvm-installer"))
        end

        it 'should set up RVM' do
          on(host, %(#{run_cmd} "rvm install 2.4.4 --disable-binary"))
          on(host, %(#{run_cmd} "rvm use --default 2.4.4"))
          on(host, %(#{run_cmd} "rvm all do gem install bundler -v \\"~> 1.16\\" --no-document"))
          on(host, %(#{run_cmd} "rvm all do gem install bundler -v \\"~> 2.0\\" --no-document"))
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
