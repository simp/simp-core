# Set up a joined SIMP server and client
#
# * Requires internet access
# * Basic configuration
#   * No LDAP
#   * No Kickstart
#   * No DNS/DHCP/TFTP
#
# Make sure you have 7G of RAM and 3 CPUs available on the system.
#
# Usage: Run `vagrant up`
#
# The password for the 'vagrant' user is 'vagrant' and will be needed to login
# to the 'simp_client' system when you use 'vagrant ssh simp_client'
#
# Environment Variables:
#   * BLEEDING_EDGE=true => Pull in the Puppetfile.branches after `simp config`
#
ENV['VAGRANT_NO_PARALLEL'] = 'yes'
ENV['SIMP_RELEASE_TYPE'] ||= 'unstable'
ENV['SIMP_VAGRANT_BOX'] ||= 'generic/centos8'
#ENV['SIMP_VAGRANT_BOX'] ||= 'centos/7'
ENV['SIMP_VAGRANT_NETWORK'] ||= '10.255.239.55'

simp_vagrant_network_base = ENV['SIMP_VAGRANT_NETWORK'].split('.')
simp_vagrant_network_start = simp_vagrant_network_base.pop.to_i
simp_vagrant_network_base = simp_vagrant_network_base.join('.')

Vagrant.configure('2') do |c|
  c.vm.define 'simp_server' do |v|
    v.vm.hostname = 'puppet.test.simp'
    v.vm.box = ENV['SIMP_VAGRANT_BOX']
    v.vm.box_check_update = 'true'

    v.vm.network 'private_network', ip: "#{simp_vagrant_network_base}.#{simp_vagrant_network_start}"

    v.vm.provider :virtualbox do |vb|
      vb.customize ['modifyvm', :id, '--memory', '6144', '--cpus', '2']
    end

    v.vm.provider :libvirt do |lv|
      lv.cpus = 2
      lv.memory = 6144
    end

    v.vm.synced_folder '.', '/vagrant', disabled: true

    v.vm.provision 'shell',
      inline: 'yum install -y https://download.simp-project.com/simp-release-community$( rpm -E %{dist} ).rpm'

    v.vm.provision 'shell',
      inline: "echo #{ENV['SIMP_RELEASE_TYPE']} > /etc/yum/vars/simpreleasetype"

    # Install the puppet server
    v.vm.provision 'shell',
      inline: 'yum install -y puppetserver'

    # Install SIMP
    v.vm.provision 'shell',
      inline: 'yum install -y simp'

    # Ensure that Vagrant can get into the system
    require 'tempfile'
    require 'yaml'

    default_hiera_shim = {
      # The wrong IP is picked up by default due to the Vagrant setup, so we
      # need to disable tihs feature.
      'simp::puppet_server_hosts_entry' => false,
      # No reason to run clamav by default, this should probably be removed
      # from the default list.
      'simp::classes' => [
        '--clamav'
      ],
      # Make sure that the Vagrant user can get back in on all hosts.
      'sudo::user_specifications' => {
        # This matches what vagrant expects for its commands
        'vagrant_su' => {
          'user_list' => ['vagrant'],
          'cmnd'      => ['ALL'],
          'passwd'    => false,
          'options'   => {
            'role' => 'unconfined_r'
          }
        }
      },
      'pam::access::users' => {
        'vagrant' => {
          'origins' => ['ALL']
        }
      }
    }

    default_yaml = Tempfile.new('default.yaml')
    default_yaml.puts(default_hiera_shim.to_yaml)
    default_yaml.close

    if default_yaml && File.exist?(default_yaml.path)
      at_exit{default_yaml.unlink}

      v.vm.provision 'file',
        source: default_yaml.path,
        destination: '/tmp/default.yaml'

      # Overwrite the defaults so that simp config slaps in the necessary file
      v.vm.provision 'shell',
        inline: '\mv /tmp/default.yaml /usr/share/simp/environment-skeleton/puppet/data/'
    end

    # Set up a STIG-mode client
    stig_mode_hiera = {
      # Enforce in STIG Mode
      'compliance_markup::enforcement' => ['disa_stig'],
      # Make sure the 'vagrant' user can get to root via sudo
      'selinux::login_resources' => {
        'vagrant' => {
          'seuser'    => 'staff_u',
          'mls_range' => 's0-s0:c0.c1023'
        }
      }
    }

    stig_yaml = Tempfile.new('stig.yaml')
    stig_yaml.puts(stig_mode_hiera.to_yaml)
    stig_yaml.close

    if stig_yaml && File.exist?(stig_yaml.path)
      at_exit{stig_yaml.unlink}

      v.vm.provision 'file',
        source: stig_yaml.path,
        destination: '/tmp/stig.test.simp.yaml'

      # Update the node-specific configuration for the stig node
      v.vm.provision 'shell',
        inline: '\mv /tmp/stig.test.simp.yaml /usr/share/simp/environment-skeleton/puppet/data/hosts'
    end

    # Hook up the compliance enforcement backend
    hiera_mod = <<~HIERA_MOD
    #!/opt/puppetlabs/puppet/bin/ruby

    require 'yaml'

    conf = '/usr/share/simp/environment-skeleton/puppet/hiera.yaml'

    hiera_yaml = YAML.load_file(conf)

    hiera_yaml['hierarchy'].insert(
      hiera_yaml['hierarchy'].index{|x| x['paths'].include?('default.yaml')},
      {'name' => 'SIMP Compliance Engine', 'lookup_key' => 'compliance_markup::enforcement'}
    )

    File.open(conf, 'w'){|f| f.puts(hiera_yaml.to_yaml)}
    HIERA_MOD

    hiera_modfile = Tempfile.new('hiera.yaml')
    hiera_modfile.puts(hiera_mod)
    hiera_modfile.close

    if hiera_modfile && File.exist?(hiera_modfile.path)
      at_exit{hiera_modfile.unlink}

      v.vm.provision 'file',
        source: hiera_modfile.path,
        destination: '/tmp/hiera_mod.rb'

      # Update the node-specific configuration for the stig node
      v.vm.provision 'shell',
        inline: '\chmod 755 /tmp/hiera_mod.rb; /tmp/hiera_mod.rb'

      v.vm.provision 'shell',
        inline: '\rm /tmp/hiera_mod.rb'
    end

    # Run simp config
    #
    # This moves the default environment data into place
    v.vm.provision 'shell',
      keep_color: true,
      inline: 'simp config --force-config -f -D -s cli::network::interface=eth1 cli::is_simp_ldap_server=false cli::network::set_up_nic=false cli::set_grub_password=false svckill::mode=enforcing cli::use_internet_simp_yum_repos=false cli::local_priv_user=vagrant'

    # Unlock bootstrap
    v.vm.provision 'shell',
      inline: 'rm -f /root/.simp/simp_bootstrap_start_lock'

    # Set up for the client registration
    #
    # Doing this now so that everything is in place after bootstrap
    # Since the system doesn't need to be kickstarted, we just need to make
    # sure that the reverse entry is in /etc/hosts
    v.vm.provision 'shell',
      inline: 'echo "10.255.239.56 client.test.simp client" >> /etc/hosts'

    v.vm.provision 'shell',
      inline: 'echo "10.255.239.57 stig.test.simp stig" >> /etc/hosts'

    # Set up the *host* PKI certificates in the secondary environment
    v.vm.provision 'shell',
      inline: 'echo client.test.simp >> /var/simp/environments/production/FakeCA/togen'

    v.vm.provision 'shell',
      inline: 'echo stig.test.simp >> /var/simp/environments/production/FakeCA/togen'

    v.vm.provision 'shell',
      inline: 'cd /var/simp/environments/production/FakeCA && ./gencerts_nopass.sh'

    # Set up the client for autosigning
    #
    # This is not security best practice but is part of the automation for this
    # example
    v.vm.provision 'shell',
      inline: 'echo client.test.simp >> /etc/puppetlabs/puppet/autosign.conf'

    v.vm.provision 'shell',
      inline: 'echo stig.test.simp >> /etc/puppetlabs/puppet/autosign.conf'

    # This lets the clients get to the necessary information for bootstrapping
    #
    # Normally, this would be part of a full kickstart setup but, in this case,
    # we don't need to manage DHCP or TFTP settings
    #
    # It's a bit of a kludge to do through shell, but this file is trying to
    # make all operations obvious.
    #
    #  Enable the kickstart class
    v.vm.provision 'shell',
      inline: %{echo "- 'simp::server::kickstart'" >> /etc/puppetlabs/code/environments/production/data/hosts/puppet.test.simp.yaml}

    #  Add a newline
    v.vm.provision 'shell',
      inline: %{echo "" >> /etc/puppetlabs/code/environments/production/data/hosts/puppet.test.simp.yaml}

    #  Disable management of DHCP
    v.vm.provision 'shell',
      inline: %{echo "simp::server::kickstart::manage_dhcp: false" >> /etc/puppetlabs/code/environments/production/data/hosts/puppet.test.simp.yaml}

    #  Disable management of TFTP
    v.vm.provision 'shell',
      inline: %{echo "simp::server::kickstart::manage_tftpboot: false" >> /etc/puppetlabs/code/environments/production/data/hosts/puppet.test.simp.yaml}

    bootstrap_cmd = [
      'simp bootstrap',
      'cp -a ~vagrant/.ssh/authorized_keys /etc/ssh/local_keys/vagrant'
    ]

    if ENV['BLEEDING_EDGE'] == 'true'
      v.vm.provision 'file',
        source: './Puppetfile.branches',
        destination: '/home/vagrant/Puppetfile.branches'

      bootstrap_cmd << 'mv /home/vagrant/Puppetfile.branches /etc/puppetlabs/code/environments/production/Puppetfile.simp'
      bootstrap_cmd << 'chown root:puppet /etc/puppetlabs/code/environments/production/Puppetfile.simp'
      bootstrap_cmd << 'chmod 0640 /etc/puppetlabs/code/environments/production/Puppetfile.simp'
      bootstrap_cmd << [
        %{( umask 0027 && sg puppet -c},
        %{'/usr/share/simp/bin/r10k puppetfile install},
        %{--puppetfile /etc/puppetlabs/code/environments/production/Puppetfile},
        %{--moduledir /etc/puppetlabs/code/environments/production/modules')}
      ].join(' ')
    end

    bootstrap_cmd << 'systemd-run --on-active=5 /bin/systemctl --force reboot'

    # Run bootstrap and ensure that Vagrant can get back into the host using
    # SSH keys
    #
    # This needs to be the LAST command run
    v.vm.provision 'shell' do |s|
      s.keep_color = true
      s.inline = bootstrap_cmd.join(' && ')
      s.reset = true
    end

    v.vm.post_up_message = <<-HEREDOC
    Your SIMP server is ready!

    If this is your first boot:

    1. Run 'vagrant ssh simp_server' to login to the system
    2. Run 'sudo su - root' to elevate privileges

    * Your server can be accessed via 'vagrant ssh simp_server'
    * Your client can be accessed via 'vagrant ssh simp_client'

    The vagrant user password is 'vagrant' should you need it
    HEREDOC
  end

  c.vm.define 'simp_client' do |v|
    v.vm.hostname = 'client.test.simp'
    v.vm.box = ENV['SIMP_VAGRANT_BOX']
    v.vm.box_check_update = 'true'

    v.vm.network 'private_network', ip: "#{simp_vagrant_network_base}.#{simp_vagrant_network_start+1}"

    v.vm.provider :virtualbox do |vb|
      vb.customize ['modifyvm', :id, '--memory', '512', '--cpus', '1']
    end

    v.vm.provider :libvirt do |lv|
      lv.cpus = 1
      lv.memory = 512
    end

    v.vm.synced_folder '.', '/vagrant', disabled: true

    # Enable the SIMP Repos from the build module
    v.vm.provision 'file',
      source: 'build/distributions/CentOS/7/x86_64/yum_data/repos/simp.repo',
      destination: '/tmp/simp.repo'

    v.vm.provision 'shell',
      inline: 'mv /tmp/simp.repo /etc/yum.repos.d'

    v.vm.provision 'shell',
      inline: 'chown root:root /etc/yum.repos.d/simp.repo'

    v.vm.provision 'shell',
      inline: 'chmod ugo+rX /etc/yum.repos.d/simp.repo'

    # Install the puppet package so that the provisioner script will work
    v.vm.provision 'shell',
      inline: 'yum -y install puppet-agent'

    # The server might be churning, so give it a bit
    v.vm.provision 'shell',
      inline: 'sleep 120'

    # DNS is not set up, so we need to make the client aware of the server
    v.vm.provision 'shell',
      inline: 'echo "10.255.239.55 puppet.test.simp puppet" >> /etc/hosts'

    # Hook into the puppet server
    v.vm.provision 'shell',
      inline: 'curl -k -O https://puppet.test.simp/ks/bootstrap_simp_client'

    v.vm.provision 'shell' do |s|
      cmd = [
        '/opt/puppetlabs/puppet/bin/ruby bootstrap_simp_client --debug --puppet-wait-for-cert 0 --debug --print-stats --puppet_server=puppet.test.simp --puppet_ca=puppet.test.simp',
        'cp -a ~vagrant/.ssh/authorized_keys /etc/ssh/local_keys/vagrant',
        'systemd-run --on-active=5 /bin/systemctl --force reboot'
      ]

      s.keep_color = true
      s.inline = cmd.join(' && ')
      s.reset = true
    end
  end

  c.vm.define 'simp_stig', autostart: false do |v|
    v.vm.hostname = 'stig.test.simp'
    v.vm.box = ENV['SIMP_VAGRANT_BOX']
    v.vm.box_check_update = 'true'

    v.vm.network 'private_network', ip: "#{simp_vagrant_network_base}.#{simp_vagrant_network_start+2}"

    v.vm.provider :virtualbox do |vb|
      vb.customize ['modifyvm', :id, '--memory', '512', '--cpus', '1']
    end

    v.vm.provider :libvirt do |lv|
      lv.cpus = 1
      lv.memory = 512
    end

    v.vm.synced_folder '.', '/vagrant', disabled: true

    # Enable the SIMP Repos from the build module
    v.vm.provision 'file',
      source: 'build/distributions/CentOS/7/x86_64/yum_data/repos/simp.repo',
      destination: '/tmp/simp.repo'

    v.vm.provision 'shell',
      inline: 'mv /tmp/simp.repo /etc/yum.repos.d'

    v.vm.provision 'shell',
      inline: 'chown root:root /etc/yum.repos.d/simp.repo'

    v.vm.provision 'shell',
      inline: 'chmod ugo+rX /etc/yum.repos.d/simp.repo'

    # Install the puppet package so that the provisioner script will work
    v.vm.provision 'shell',
      inline: 'yum -y install puppet-agent'

    # The server might be churning, so give it a bit
    v.vm.provision 'shell',
      inline: 'sleep 120'

    # DNS is not set up, so we need to make the client aware of the server
    v.vm.provision 'shell',
      inline: 'echo "10.255.239.55 puppet.test.simp puppet" >> /etc/hosts'

    # Hook into the puppet server
    v.vm.provision 'shell',
      inline: 'curl -k -O https://puppet.test.simp/ks/bootstrap_simp_client'

    v.vm.provision 'shell' do |s|
      cmd = [
        '/opt/puppetlabs/puppet/bin/ruby bootstrap_simp_client --debug --puppet-wait-for-cert 0 --debug --print-stats --puppet_server=puppet.test.simp --puppet_ca=puppet.test.simp',
        'cp -a ~vagrant/.ssh/authorized_keys /etc/ssh/local_keys/vagrant',
        'systemd-run --on-active=5 /bin/systemctl --force reboot'
      ]

      s.keep_color = true
      s.inline = cmd.join(' && ')
      s.reset = true
    end

    v.vm.post_up_message = <<-HEREDOC
    Your  STIG-mode SIMP client is ready!

    * This sytem can be accessed via 'vagrant ssh simp_stig'
    * The vagrant user password is 'vagrant'.
    HEREDOC
  end
end
