# You can set the following environment variables to affect this test
#
# * SIMP_BEAKER_build_version => The git branch that you want to use
# * SIMP_BEAKER_build_map     => The release_mapper.yaml key that you want to use
#
require 'spec_helper_acceptance'

test_name 'iso build'

sys_iso_dir = File.expand_path(File.join(fixtures_path, 'ISO'))

if ENV['SIMP_BEAKER_iso_dir']
  sys_iso_dir = File.expand_path(ENV['SIMP_BEAKER_iso_dir'])
end

unless File.directory?(sys_iso_dir)
  fail(%(Error: The ISO directory '#{sys_iso_dir}' could not be read))
end

if Dir.glob(File.join(sys_iso_dir, '*.iso')).empty?
  fail(%(Error: The ISO directory '#{sys_iso_dir}' contains no ISO images))
end

# Custom Gemfile Support
gemfile = nil
gemfile_path = File.expand_path(File.join(fixtures_path,'Gemfile'))

if File.file?(gemfile_path)
  gemfile = gemfile_path
end

describe 'iso build' do
  context 'build SIMP ISO' do

    let(:source_repo) { 'https://github.com/simp/simp-core' }

    let(:iso_dir) { sys_iso_dir }

    # We need a normal user for running mock
    let(:build_user) { 'build_user' }
    let(:run_cmd) {
      %(runuser #{build_user} -l -c )
    }

    # The branches inside of simp-core that should be built
    #
    # The hash should be of the form:
    # {
    #   'BRANCH' => 'Build Target from release_mappings.yaml'
    # }
    let(:build_branches) {
      to_build = {}

      if ENV['SIMP_BEAKER_build_version']
        to_build[ENV['SIMP_BEAKER_build_version']] = ''

        if ENV['SIMP_BEAKER_build_map']
          to_build[ENV['SIMP_BEAKER_build_version']] = ENV['SIMP_BEAKER_build_map']
        else
          to_build[ENV['SIMP_BEAKER_build_version']] = ENV['SIMP_BEAKER_build_version']
        end
      else
        to_build = {
          '5.1.X' => '5.1.X',
          '4.2.X' => '4.2.X',
          'DentAuthurDent' => '5.1.X'
        }
      end

      to_build
    }

    hosts.each do |host|

      unless host[:hypervisor] == 'docker'
        it 'should enable haveged on the system' do
          host.install_package('haveged')

          on(host, 'puppet resource service haveged ensure=running enable=true')
        end

        it 'should add the build user to the system' do
          on(host, %(useradd -b /home -m -c 'Build User' -s /bin/bash -U #{build_user}))
          on(host, %(echo 'Defaults:#{build_user} !requiretty' >> /etc/sudoers))
          on(host, %(echo '#{build_user} ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers))
          on(host, %(#{run_cmd} "ls"))
        end

        it 'should have all the required packages' do
          required_packages = [
            'util-linux',
            'mock',
            'augeas-devel',
            'createrepo',
            'genisoimage',
            'git',
            'libicu-devel',
            'libxml2',
            'libxml2-devel',
            'libxslt',
            'libxslt-devel',
            'rpmdevtools',
            'gcc',
            'gcc-c++',
            'ruby-devel',
            'rpm-build',
            'rpm-devel',
            'rpm-sign'
          ]

          os = fact_on(host, 'operatingsystem')
          os_version = fact_on(host, 'operatingsystemmajrelease')

          if ['CentOS','RedHat'].include?(os)
            required_packages << 'gnupg2'

            if os_version.to_i > 6
              required_packages << 'clamav-update'
            else
              required_packages << 'clamav'
            end
          end

          if ['Fedora'].include?(os)
            required_packages << 'gnupg'
            required_packages << 'clamav-update'
          end

          required_packages.each do |pkg|
            host.install_package(pkg)
          end
        end

        it 'should add the user to the "mock" group' do
          on(host, %(usermod -a -G mock #{build_user}))
        end

        it 'should install RVM' do
          on(host, %(#{run_cmd} "gpg2 --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3"))
          on(host, %(#{run_cmd} "curl -sSL https://get.rvm.io | bash -s stable --ruby=2.1"))
          on(host, %(#{run_cmd} "rvm use --default 2.1"))
          on(host, %(#{run_cmd} "rvm all do gem install bundler"))
        end
      end

      it 'should have the ISOs' do
        if host[:hypervisor] == 'docker'
          %x(docker cp #{iso_dir} #{host[:docker_container].id}:/)
        else
          scp_to(host, "#{iso_dir}", '/ISO')
        end
      end

      it 'should clone the main repos' do
        build_branches.each_key do |branch|
          on(host, %(#{run_cmd} "git clone -b #{branch} #{source_repo} #{branch}"))
        end
      end

      if gemfile
        it 'should have a custom Gemfile' do
          scp_to(host, gemfile, '/tmp/Gemfile')
          build_branches.each_key do |branch|
            on(host, %(#{run_cmd} "cp /tmp/Gemfile #{branch}"))
          end
        end
      end

      it 'should build and retrieve the releases' do
        require 'time'
        timestamp = Time.now.iso8601

        build_branches.each_pair do |branch, release_version|

          on(host, %(#{run_cmd} "rvm use default; cd #{branch}; bundle update"))
          on(host, %(#{run_cmd} "rvm use default; cd #{branch}; rake build:auto[#{release_version},/ISO]"))

          target_dir = File.expand_path("SIMP_ISO/rake_generated/#{branch}/#{timestamp}")
          FileUtils.mkdir_p(target_dir) unless File.directory?(target_dir)

          iso_dir = %(/home/build_user/#{branch}/SIMP_ISO)

          # Snag all output files from the host. 'scp_from' doesn't support globbing
          on(host, %(ls "#{iso_dir}")).stdout.split.each do |file|
            # We only need one...
            target_file = File.join(target_dir, file)
            unless (File.exist?(target_file) && (File.size(target_file) != 0))
              src_file = File.join(iso_dir, file)

              if host[:hypervisor] == 'docker'
                %x(docker cp #{host[:docker_container].id}:#{src_file} #{target_dir})
              else
                scp_from(host, src_file, target_dir)
              end
            end
          end
        end
      end
    end
  end
end
