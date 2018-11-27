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
  env_string
end


# Custom Gemfile Support
gemfile = nil
gemfile_path = File.expand_path(File.join(fixtures_path,'Gemfile'))

if File.file?(gemfile_path)
  gemfile = gemfile_path
end

describe 'RPM build' do
  let(:local_basedir) { File.absolute_path(Dir.pwd) }

  # We need a normal user for building the RPMs
  let(:build_user) { 'build_user' }
  let(:run_cmd) { %(runuser #{build_user} -l -c ) }


  hosts.each do |host|
    next if host[:roles].include?('disabled')

    # This needs to happen *prior* to the test selection since the test
    # selection depends on this being present
    if ENV['BEAKER_copyin'] == 'yes'
      %x(docker cp #{Dir.pwd} #{host.host_hash[:docker_container].id}:#{build_dir})
    end

    it 'should clone the repo if necessary' do
      set_perms = false

      if ENV['BEAKER_copyin'] == 'yes'
        set_perms = true
      elsif !host.file_exist?("#{build_dir}/metadata.json")
        # Handle Travis CI first
        if ENV['TRAVIS_BUILD_DIR']
          base_dir = File.dirname(ENV['TRAVIS_BUILD_DIR'])

puts host.host_hash
          %x(docker cp #{ENV['TRAVIS_BUILD_DIR']} #{host.host_hash[:docker_container].id}:#{build_dir})

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

    it 'should have the latest gems' do
      on(host, "#{run_cmd} 'cd #{local_basedir}; bundle update'")


      on(host, "#{run_cmd} 'cd #{local_basedir}; bundle config'")
      on(host, "#{run_cmd} 'cd #{local_basedir}; bundle exec gem env'")
      on(host, "#{run_cmd} 'cd #{local_basedir}; gem env'")
      on(host, "#{run_cmd} 'cd #{local_basedir}; bundle pristine'")
    end

    if host.file_exist?("#{build_dir}/ISO")
      it 'should be able to build the ISO' do
        on(host, "#{run_cmd} 'cd #{local_basedir}; SIMP_BUILD_docs=yes SIMP_BUILD_prompt=no #{get_test_env} bundle exec rake build:auto[ISO]'")
      end
    else
      it 'should have all of the dependencies' do
        on(host, "#{run_cmd} 'cd #{local_basedir}; bundle exec rake deps:checkout'")
      end

      it 'should be able to build all modules ' do
        on(host, "#{run_cmd} 'cd #{local_basedir}; #{get_test_env} bundle exec rake pkg:modules'")
      end

      it 'should be able to build aux packages ' do
        on(host, "#{run_cmd} 'cd #{local_basedir}; #{get_test_env} bundle exec rake pkg:aux'")
      end
    end
  end
end
