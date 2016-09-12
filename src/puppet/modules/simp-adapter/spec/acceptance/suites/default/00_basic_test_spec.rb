require 'spec_helper_acceptance'

test_name 'simp-adapter'

describe 'simp-adapter' do

  rpm_src = File.join(fixtures_path,'dist')
  stub_rpm_src = File.join(fixtures_path,'test_module_rpms')

  local_yum_repo = '/srv/local_yum'
  local_yum_repo_conf =<<-EOM
[local_yum]
name=Local Repos
baseurl=file://#{local_yum_repo}
enabled=1
gpgcheck=0
repo_gpgcheck=0
  EOM

  hosts.each do |host|
    install_target = host.puppet['codedir']
    if !install_target || install_target.empty?
      install_target = host.puppet['confdir']
    end

    let(:install_target) { install_target }
    let(:site_module_init) { "#{install_target}/environments/simp/modules/site/init.pp" }
    let(:site_manifest) {
      <<-EOM
class site {
  notify { "Hark! A Site!": }
}
      EOM
    }

    context 'Setting up' do
      it 'should have git' do
        host.install_package('git')
        on(host,'git config --global user.email "root@rooty.tooty"')
        on(host,'git config --global user.name "Rootlike Overlord"')
      end
    end

    context 'Building The RPM' do
      it 'should build cleanly' do
        Bundler.with_clean_env do
          %x{rake clean}
          %x{rake pkg:rpm[#{host[:mock_chroot]},true]}
        end
      end
    end

    context 'Installing The RPM' do
      it 'should have the RPMs in a local repo' do
        on(host, "mkdir -p #{local_yum_repo}")

        src_rpms = []
        src_rpms += Dir.glob(File.join(rpm_src,host[:rpm_glob]))
        src_rpms += Dir.glob(File.join(stub_rpm_src,'*.rpm'))

        src_rpms.each do |rpm|
          if host[:hypervisor] == 'docker'
            %x{docker cp #{rpm} #{host[:docker_container].id}:#{local_yum_repo}}
          else
            scp_to(host, rpm, local_yum_repo)
          end
        end
      end

      it 'should have a local yum repo' do
        host.install_package('createrepo')
        host.install_package('yum-utils')
        on(host, "cd #{local_yum_repo} && createrepo .")
        create_remote_file(host, '/etc/yum.repos.d/beaker_local.repo', local_yum_repo_conf)
      end

      it 'should have a "site" module' do
        host.mkdir_p(File.dirname(site_module_init))
        create_remote_file(host, site_module_init, site_manifest)
      end

      it 'should install cleanly' do
        host.install_package('pupmod-simp-beakertest')
        on(host, 'test -d /usr/share/simp/modules/beakertest')
        host.check_for_package('simp-adapter')
      end

      it 'should NOT copy anything by default' do
        on(host, "test ! -d #{install_target}/environments/simp/modules/beakertest")
        on(host, "test ! -f #{install_target}/environments/simp/test_file")
      end
    end

    context 'When Configured to Copy Data via the Config File' do
      it 'should start in a clean state' do
        host.uninstall_package('pupmod-simp-beakertest')
        host.uninstall_package('simp-environment')

        config_yaml =<<-EOM
---
copy_rpm_data : true
this_should_not_break_things : awwww_yeah
        EOM
        create_remote_file(host, '/etc/simp/simp_adapter_config.yaml', config_yaml)
      end

      it 'should copy the module data into the appropriate location' do
        host.install_package('pupmod-simp-beakertest')
        on(host, "test -d #{install_target}/environments/simp/modules/beakertest")
        on(host, "diff -aqr /usr/share/simp/modules/beakertest #{install_target}/environments/simp/modules/beakertest")
      end

      it 'should have the environment data in the appropriate location' do
        host.install_package('simp-environment')
        on(host, "test -f #{install_target}/environments/simp/test_file")
        expect(
          on(host, "cat #{install_target}/environments/simp/test_file").output
        ).to match(%r{Just testing stuff})
      end

      it 'should uninstall cleanly' do
        host.uninstall_package('pupmod-simp-beakertest')
        host.uninstall_package('simp-environment')
        on(host, 'test ! -d /usr/share/simp/modules/beakertest')
        on(host, "test ! -d #{install_target}/environments/simp/modules/beakertest")
        on(host, "test ! -f #{install_target}/environments/simp/test_file")
      end
    end

    context "Installing with an already managed target" do
      it 'should have a git managed beakertest module' do
        host.mkdir_p("#{install_target}/environments/simp/modules/beakertest")
        create_remote_file(host, "#{install_target}/environments/simp/modules/beakertest/test_file", '# IMA TEST')
        on(host, "cd #{install_target}/environments/simp/modules/beakertest && git init . && git add . && git commit -a -m woo")
      end

      it 'should have a git managed simp environment' do
        create_remote_file(host, "#{install_target}/environments/simp/git_controlled_file", '# IMA TEST')
        on(host, "cd #{install_target}/environments/simp && git init . && git add git_controlled_file && git commit -a -m woo")
      end

      it 'should install cleanly' do
        host.install_package('simp-environment')
        host.install_package('pupmod-simp-beakertest')
        on(host, 'test -d /usr/share/simp/modules/beakertest')
      end

      it 'should NOT copy the module data into the $codedir' do
        on(host, "test -d #{install_target}/environments/simp/modules/beakertest")
        on(
          host,
          "diff -aqr /usr/share/simp/modules/beakertest #{install_target}/environments/simp/modules/beakertest",
          :acceptable_exit_codes => [1]
        )
        expect(
          on(host, "cat #{install_target}/environments/simp/modules/beakertest/test_file").output
        ).to match(%r{IMA TEST})
      end

      it 'should uninstall cleanly' do
        host.uninstall_package('pupmod-simp-beakertest')
        host.uninstall_package('simp-environment')
        on(host, 'test ! -d /usr/share/simp/modules/beakertest')
        on(host, 'test ! -f /usr/share/simp/environment/simp/test_file')
      end

      it 'should NOT remove the functional module from the system' do
        on(host, "test -d #{install_target}/environments/simp/modules/beakertest")
      end

      it 'should NOT remove the git controlled environment materials from the system' do
        on(host, "test -f #{install_target}/environments/simp/git_controlled_file")
      end

      it 'should NOT affect the "site" module' do
        expect(
          on(host, "cat #{site_module_init}").output.strip
        ).to eq(site_manifest.strip)
      end
    end
  end
end
