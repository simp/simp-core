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
# Once the systems have completed:
#   * vagrant ssh simp_server
#   * sudo su - root
#   * reboot
#
# The password for the 'vagrant' user is 'vagrant' and will be needed to login
# to the 'simp_client' system when you use 'vagrant ssh simp_client'
Vagrant.configure('2') do |c|
  c.vm.define 'simp_server' do |v|
    v.vm.hostname = 'puppet.test.simp'
    v.vm.box = 'centos/7'
    v.vm.box_check_update = 'true'

    v.vm.network 'private_network', ip: '10.255.239.55'

    v.vm.provider :virtualbox do |vb|
      vb.customize ['modifyvm', :id, '--memory', '6144', '--cpus', '2']
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
          'passwd'    => false
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

    at_exit{default_yaml.unlink}

    v.vm.provision 'file',
      source: default_yaml.path,
      destination: '/tmp/default.yaml'

    # Overwrite the defaults so that simp config slaps in the necessary file
    v.vm.provision 'shell',
      inline: '\mv /tmp/default.yaml /usr/share/simp/environment-skeleton/puppet/data/'

    # Run simp config
    v.vm.provision 'shell',
      keep_color: true,
      inline: 'simp config --force-config -f -D -s cli::network::interface=eth1 cli::is_simp_ldap_server=false cli::network::dhcp=static cli::set_grub_password=false svckill::mode=enforcing'

    # Unlock bootstrap
    v.vm.provision 'shell',
      inline: 'rm /root/.simp/simp_bootstrap_start_lock'

    # Set up for the client registration
    #
    # Doing this now so that everything is in place after bootstrap
    # Since the system doesn't need to be kickstarted, we just need to make
    # sure that the reverse entry is in /etc/hosts
    v.vm.provision 'shell',
      inline: 'echo "10.255.239.56 client.test.simp client" >> /etc/hosts'

    # Set up the *host* PKI certificates in the secondary environment
    v.vm.provision 'shell',
      inline: 'echo client.test.simp > /var/simp/environments/production/FakeCA/togen'

    v.vm.provision 'shell',
      inline: 'cd /var/simp/environments/production/FakeCA && ./gencerts_nopass.sh'

    # Set up the client for autosigning
    #
    # This is not security best practice but is part of the automation for this
    # example
    v.vm.provision 'shell',
      inline: 'echo client.test.simp >> /etc/puppetlabs/puppet/autosign.conf'

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
      inline: %{echo "  - 'simp::server::kickstart'" >> /etc/puppetlabs/code/environments/production/data/hosts/puppet.test.simp.yaml}

    #  Add a newline
    v.vm.provision 'shell',
      inline: %{echo "" >> /etc/puppetlabs/code/environments/production/data/hosts/puppet.test.simp.yaml}

    #  Disable management of DHCP
    v.vm.provision 'shell',
      inline: %{echo "simp::server::kickstart::manage_dhcp: false" >> /etc/puppetlabs/code/environments/production/data/hosts/puppet.test.simp.yaml}

    #  Disable management of TFTP
    v.vm.provision 'shell',
      inline: %{echo "simp::server::kickstart::manage_tftpboot: false" >> /etc/puppetlabs/code/environments/production/data/hosts/puppet.test.simp.yaml}

    # Run bootstrap and ensure that Vagrant can get back into the host using
    # SSH keys
    #
    # This needs to be the LAST command run
    v.vm.provision 'shell',
      keep_color: true,
      inline: 'simp bootstrap && cp -a ~vagrant/.ssh/authorized_keys /etc/ssh/local_keys/vagrant'

    v.vm.post_up_message = <<-EOM
    Your SIMP server is ready!

    If this is your first boot:

    1. Run 'vagrant ssh simp_server' then 'sudo reboot' to restart the server
    2. Run 'vagrant ssh simp_server' to login to the system
    3. Run 'sudo su - root' to elevate privileges

    * Your server can be accessed via 'vagrant ssh simp_server'
    * Your client can be accessed via 'vagrant ssh simp_client'

    The vagrant user password is 'vagrant' should you need it
    EOM
  end

  c.vm.define 'simp_client' do |v|
    v.vm.hostname = 'client.test.simp'
    v.vm.box = 'centos/7'
    v.vm.box_check_update = 'true'

    v.vm.network 'private_network', ip: '10.255.239.56'

    v.vm.provider :virtualbox do |vb|
      vb.customize ['modifyvm', :id, '--memory', '512', '--cpus', '1']
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
      inline: 'yum -y install puppet'

    # The server might be churning, so give it a bit
    v.vm.provision 'shell',
      inline: 'sleep 120'

    # DNS is not set up, so we need to make the client aware of the server
    v.vm.provision 'shell',
      inline: 'echo "10.255.239.55 puppet.test.simp client" >> /etc/hosts'

    # Hook into the puppet server
    v.vm.provision 'shell',
      inline: 'curl -k -O https://puppet.test.simp/ks/runpuppet'

    v.vm.provision 'shell',
      inline: 'bash runpuppet start'
  end
end
