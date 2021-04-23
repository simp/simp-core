require_relative '../helpers'
require 'erb'
require 'pathname'

include Acceptance::Helpers::PasswordHelper
include Acceptance::Helpers::PuppetHelper
include Acceptance::Helpers::Utils

# config keys:
#   :domain                 - (REQUIRED) test domain
#   :master_fqdn            - (REQUIRED) FQDN of the puppetmaster
#   :syslog_server_fqdns    - (REQUIRED) array of syslog server FQDNs
#   :simp_config_extra_args - (OPTIONAL) array of additional arguments
#                             to be passed to simp config
#   :simp_ldap_server       - (OPTIONAL) whether to configure the SIMP
#                             server as a SIMP LDAP server; defaults
#                             to true
#   :other_hiera            - (OPTIONAL) Hash of other hieradata to be
#                             set.  Will be merged with the standard
#                             hieradata.
#
shared_examples 'SIMP server bootstrap' do |master, config|

  let(:domain) { config[:domain] }
  let(:master_fqdn) { config[:master_fqdn] }
  let(:puppetserver_status_cmd) { puppetserver_status_command(master_fqdn) }
  let(:syslog_server_fqdns) { config[:syslog_server_fqdns] }
  let(:production_env_dir) { '/etc/puppetlabs/code/environments/production' }

  let(:default_hieradata) {
    # hieradata that allows beaker operations access
    beaker_hiera = YAML.load(File.read('spec/acceptance/common_files/beaker_hiera.yaml'))

    # set up syslog forwarding
    hiera = beaker_hiera.merge( {
      'simp::rsync_stunnel'         => master_fqdn,
      'rsyslog::enable_tls_logging' => true,
      'simp_rsyslog::forward_logs'  => true
    } )

    if config.has_key?(:other_hiera)
      hiera.merge!( config[:other_hiera] )
    end

    hiera
  }

  # remote syslog server hieradata
  let(:syslog_server_hieradata) { {
    'rsyslog::tls_tcp_server'    => true,
    'simp_rsyslog::is_server'    => true,
    'simp_rsyslog::forward_logs' => false
  } }

  context 'puppet master' do
    let(:simp_conf_template) {
      if config.fetch(:simp_ldap_server, true)
        File.read('spec/acceptance/common_files/simp_conf.yaml.erb')
      else
        File.read('spec/acceptance/common_files/simp_conf.yaml_no_ldap.erb')
      end
    }

    it 'should create answers file for simp config' do
      # The following variables are required by both simp_conf.yaml.erb:
      # and simp_conf.yaml_no_ldap.erb
      #   domain
      #   grub_password_hash
      #   interface
      #   ipaddress
      #   master_fqdn
      #   nameserver
      #   netmask
      #   syslog_server_fqdns
      #   trusted_nets
      #
      # The following variables are require only by simp_conf.yaml.erb
      #   ldap_root_password_hash
      #
      # The following variables are require only by simp_conf.yaml_no_ldap.erb
      #   sssd_domains

      trusted_nets =  host_networks(master)
      expect(trusted_nets).to_not be_empty

      network_info = internal_network_info(master)
      expect(network_info).to_not be_nil
      interface = network_info[:interface]
      ipaddress = network_info[:ip]
      netmask   = network_info[:netmask]

      nameserver = dns_nameserver(master)
      expect(nameserver).to_not be_nil

      grub_password_hash = encrypt_grub_password(master, test_password)

      if config.fetch(:simp_ldap_server, true)
        ldap_root_password_hash = encrypt_openldap_password(test_password)
      else
        el7_master = (fact_on(master, 'operatingsystemmajrelease') == '7')
        sssd_domains = el7_master ? ['local'] : []
      end

      if config.has_key?(:simp_scenario)
        scenario = config[:simp_scenario]
      else
        scenario = 'simp'
      end

      create_remote_file(master, '/root/simp_conf.yaml', ERB.new(simp_conf_template).result(binding))
      on(master, 'cat /root/simp_conf.yaml')
    end

    it 'should run simp config' do
      if config.has_key?(:simp_config_extra_args)
        extra_args = config[:simp_config_extra_args].join(' ')
      else
        extra_args = ''
      end

      on(master, "simp config -a /root/simp_conf.yaml #{extra_args}")
      on(master, 'cat /root/.simp/simp_conf.yaml')
    end

    it 'should provide default hieradata' do
      create_remote_file(master, "#{production_env_dir}/data/default.yaml", default_hieradata.to_yaml)
      on(master, 'simp environment fix production --no-secondary-env --no-writable-env')
    end

    it 'should provide syslog server hieradata' do
      syslog_server_fqdns.each do |server|
        host_yaml_file = "#{production_env_dir}/data/hosts/#{server}.yaml"
        create_remote_file(master, host_yaml_file, syslog_server_hieradata.to_yaml)
      end
      on(master, 'simp environment fix production --no-secondary-env --no-writable-env')
    end

    it 'should enable Puppet autosign for hosts on the domain' do
      enable_puppet_autosign(master, domain)
    end

    it 'should run simp bootstrap' do
      # NOTE:
      # - Remove the lock file because we've already added the vagrant user
      #   access and won't be locked out of the VM
      # - Remove the puppet certs for the puppet agent already created
      #   when the puppetserver RPM was installed
      # - Allow interruptions so we can kill the test easily during bootstrap
      on(master, 'rm -f /root/.simp/simp_bootstrap_start_lock')
      on(master, 'simp bootstrap -u -w 10 --remove_ssldir -v', :pty => true)
    end

    it 'should reboot the master to apply boot time config' do
      master.reboot
    end

    it 'should complete the config with a few puppet runs' do
      # Wait for the puppetserver to be ready to receive requests
      retry_on(master, puppetserver_status_cmd, :retry_interval => 10)

      # Run puppet until no more changes are required
      retry_on(master, '/opt/puppetlabs/bin/puppet agent -t',
        :desired_exit_codes => [0],
        :retry_interval     => 15,
        :max_retries        => 3,
        :verbose            => true.to_s # work around beaker bug
      )
    end
  end
end
