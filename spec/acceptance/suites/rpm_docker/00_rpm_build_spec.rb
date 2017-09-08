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

  before(:all) do
    @build_dir = '/simp-core'

    if ENV['BEAKER_copyin']
      @build_dir = '/simp-import'
    end
  end

  hosts.each do |host|
    next if host[:roles].include?('disabled')

    it 'should clone the repo if necessary' do
      set_perms = false

      if ENV['BEAKER_copyin'] == 'yes'
        %x(docker cp #{Dir.pwd} #{host.name}:#{@build_dir})
        set_perms = true
      elsif !host.file_exist?("#{@build_dir}/metadata.json")
        # Handle Travis CI first
        if ENV['TRAVIS_BUILD_DIR']
          base_dir = File.dirname(ENV['TRAVIS_BUILD_DIR'])

          %x(docker cp #{ENV['TRAVIS_BUILD_DIR']} #{host.name}:#{@build_dir})

          host.mkdir_p(base_dir)
          on(host, %(cd #{base_dir}; ln -s #{@build_dir} .))
        else
          # Just clone the main simp repo
          on(host, %(git clone https://github.com/simp/simp-core #{@build_dir}))
        end

        set_perms = true
      end

      if set_perms
        on(host, %(chown -R #{build_user}:#{build_user} #{@build_dir}))
      end
    end

    it 'should have access to the local simp-core' do

      # This is to work around irritating artifacts left around by r10k
      unless local_basedir == @build_dir
        host.mkdir_p(File.dirname(local_basedir))

        on(host, %(cd #{File.dirname(local_basedir)}; ln -s #{@build_dir} #{File.basename(local_basedir)}))
      end

      host.file_exist?("#{local_basedir}/metadata.json")
    end

    it 'should align the build user uid and gid with the mounted filesystem' do
      on(host, %(groupmod -g `stat --printf="%g" #{@build_dir}` #{build_user}))
      on(host, %(usermod -u `stat --printf="%u" #{@build_dir}` -g `stat --printf="%g" #{@build_dir}` #{build_user}))
      on(host, %(chown -R #{build_user}:#{build_user} ~#{build_user}))
    end

    it 'should have the latest gems' do
      on(host, "#{run_cmd} 'cd #{local_basedir}; bundle update'")
    end

    if host.file_exist?("#{@build_dir}/ISO")
      it 'should be able to build the ISO' do
        on(host, "#{run_cmd} 'cd #{local_basedir}; bundle exec rake build:auto[ISO]'")
      end
    else
      it 'should have all of the dependencies' do
        on(host, "#{run_cmd} 'cd #{local_basedir}; bundle exec rake deps:checkout'")
      end

      it 'should be able to build all modules ' do
        on(host, "#{run_cmd} 'cd #{local_basedir}; bundle exec rake pkg:modules'")
      end

      it 'should be able to build aux packages ' do
        on(host, "#{run_cmd} 'cd #{local_basedir}; bundle exec rake pkg:aux'")
      end
    end
  end
end
