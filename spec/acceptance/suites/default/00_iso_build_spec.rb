require 'spec_helper_acceptance'

test_name 'iso build'

unless ENV['SIMP_BEAKER_iso_dir']
  fail('Error: You must specify the ISO directory with SIMP_BEAKER_iso_dir')
end

unless File.directory?(ENV['SIMP_BEAKER_iso_dir'])
  fail('Error: The SIMP_BEAKER_iso_dir could be be read')
end

describe 'iso build' do
  context 'build SIMP ISO' do

    let(:source_repo) { 'https://github.com/simp/simp-core' }

    let(:iso_dir) { ENV['SIMP_BEAKER_iso_dir'] }

    # We need a normal user for running mock
    let(:build_user) { 'build_user' }
    let(:run_cmd) {
      %(runuser #{build_user} -l -c )
    }

    # The branches inside of simp-core that should be built
    let(:build_branches) {
      to_build = []

      if ENV['SIMP_BEAKER_build_version']
        to_build << ENV['SIMP_BEAKER_build_version']
      else
        to_build = [
          '5.1.X',
          '4.2.X'
        ]
      end

      to_build
    }

    hosts.each do |host|

      it 'should add the build user to the system' do
        on(host, %(useradd -b /home -m -c 'Build User' -s /bin/bash -U #{build_user}))
        on(host, %(echo 'Defaults:#{build_user} !requiretty' >> /etc/sudoers))
        on(host, %(echo '#{build_user} ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers))
        on(host, %(#{run_cmd} "ls"))
      end

      it 'should have the ISOs' do
        scp_to(host, "#{iso_dir}", '/ISO')
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
          'rpm-devel'
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

      it 'should clone the main repos' do
        build_branches.each do |branch|
          on(host, %(#{run_cmd} "git clone -b #{branch} #{source_repo} #{branch}"))
        end
      end

      it 'should build and retrieve the releases' do
        require 'time'
        timestamp = Time.now.iso8601

        build_branches.each do |branch|

          on(host, %(#{run_cmd} "rvm use default; cd #{branch}; bundle update"))
          on(host, %(#{run_cmd} "rvm use default; cd #{branch}; rake build:auto[#{branch},/ISO]"))

          target_dir = File.expand_path("SIMP_ISO/rake_generated/#{branch}/#{timestamp}")
          FileUtils.mkdir_p(target_dir) unless File.directory?(target_dir)

          iso_dir = %(/home/build_user/#{branch}/SIMP_ISO)

          # Snag all output files from the host. 'scp_from' doesn't support globbing
          on(host, %(ls "#{iso_dir}")).stdout.split.each do |file|
            # We only need one...
            target_file = File.join(target_dir, file)
            unless (File.exist?(target_file) && (File.size(target_file) != 0))
              scp_from(host, File.join(iso_dir, file), target_dir)
            end
          end
        end
      end
    end
  end
end
