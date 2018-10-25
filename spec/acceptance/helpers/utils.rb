module Acceptance
  module Helpers
    module Utils

      def puppetserver_status_command(master_fqdn)
        [
          'curl -sk',
          "--cert /etc/puppetlabs/puppet/ssl/certs/#{master_fqdn}.pem",
          "--key /etc/puppetlabs/puppet/ssl/private_keys/#{master_fqdn}.pem",
          "https://#{master_fqdn}:8140/status/v1/services",
          '| python -m json.tool',
          '| grep state',
          '| grep running'
        ].join(' ')
      end

      # @returns array of IPV4 networks configured on a host
      #
      # +host+: Host (object)
      #
      def host_networks(host)
        require 'json'
        require 'ipaddr'
        networking = JSON.load(on(host, 'facter --json networking').stdout)
        networking['networking']['interfaces'].delete_if { |key,value| key == 'lo' }
        networks = networking['networking']['interfaces'].map do |key,value|
          net_mask = IPAddr.new(value['netmask']).to_i.to_s(2).count("1")
          "#{value['network']}/#{net_mask}"
        end
        networks
      end

      # @returns the DHCP info for the first DHCP interface or nil if there is no
      #   interface configured via DHCP
      def dhcp_info(host)
        networking = JSON.load(on(host, 'facter --json networking').stdout)
        networking['networking']['interfaces'].delete_if { |interface,settings| !settings.has_key?('dhcp') }
        dchp_info = nil
        unless networking['networking']['interfaces'].empty?
          interface,settings = networking['networking']['interfaces'].first
          dhcp_info = {
            :interface => interface,
            :ip        => settings['ip'],
            :netmask   => settings['netmask'],
            :gateway   => settings['dhcp']
          }
        end
        dhcp_info
      end

      # @returns the internal IPV4 network address for a host or nil if
      #   none can be found
      #
      # +host+: Host (object)
      #
      # This method ASSUMES the first non-loopback interface without DHCP
      # configured is the interface used for the internal network.
      def internal_network_address(host)
        networking = JSON.load(on(host, 'facter --json networking').stdout)
        internal_ip_addr = nil
        networking['networking']['interfaces'].each do |interface,settings|
          next if interface == 'lo'
          unless settings.has_key?('dhcp')
            internal_ip_addr = settings['ip']
            break
          end
        end
        internal_ip_addr
      end

      # @returns DNS nameserver used by the host or nil if it cannot be determined
      #
      # +host+: Host (object)
      def dns_nameserver(host)
        dig_result = on(host, "dig #{host.name}", :accept_all_exit_codes => true)
        nameserver = nil
        if dig_result.exit_code == 0
          match = dig_result.stdout.match(/\n;; SERVER:.*\((.*)\)\s*\n/)
          unless match.nil?
            nameserver = match[1]
          end
        end
        nameserver
      end

      # Enables autosign for any host in the domain on the master
      #
      # TODO:  pass in a array of Hosts (objects) and add each one
      # to the autosign.conf, in lieu of this lazy *.<domain>
      # configuration
      def enable_puppet_autosign(master, domain)
        result = on(master, 'puppet config print --section master autosign')
        autosign_file = result.stdout.strip
        on(master, "echo '*.#{domain}' >> #{autosign_file}")
        on(master, "chmod 644 #{autosign_file}")
        on(master, "grep #{domain} #{autosign_file}")
      end

      # Generates application certs for hosts on the puppet master
      # using the FakeCA
      #
      # +master+: Host (object) for the puppet master
      # +hosts+: Array of hosts (objects)
      # +domain+: The domain for the hosts
      # +skip_master+: Whether to skip generating application certs for
      #   the puppet master.  This is appropriate when 'simp config' has
      #   already generated those certs.
      def generate_application_certs(master, hosts, domain, skip_master = true)
        togen = []
        hosts.each do |host|
          next if (host['roles'].include?('master') and skip_master)
          togen << host.hostname + '.' + domain
        end
        create_remote_file(master, '/var/simp/environments/production/FakeCA/togen', togen.join("\n"))
        on(master, 'cd /var/simp/environments/production/FakeCA; ./gencerts_nopass.sh')
      end

    end
  end
end
