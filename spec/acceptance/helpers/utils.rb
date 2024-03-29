module Acceptance
  module Helpers
    module Utils

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

      # @returns the internal IPV4 network info for a host or nil if
      #   none can be found
      #
      # +host+: Host (object)
      #
      def internal_network_info(host)
        networking = JSON.load(on(host, 'facter --json networking').stdout)

        # this is the IP address beaker puts into /etc/hosts
        internal_ip = host['vm_ip'] || host['ip'].to_s

        internal_ip_info = nil
        networking['networking']['interfaces'].each do |interface,settings|
          if ( settings['ip'] and settings['ip'] == internal_ip )
            internal_ip_info = {
              :interface => interface,
              :ip        => settings['ip'],
              :netmask   => settings['netmask']
            }
            break
          end
        end

        internal_ip_info
      end

      # @returns DNS nameserver used by the host or nil if it cannot be determined
      #
      # +host+: Host (object)
      def dns_nameserver(host)
        host.install_package('bind-utils') # for dig
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

          fqdn = pfact_on(host, 'fqdn')
          if fqdn.include?('.')
            togen << fqdn
          else
            togen << host.hostname + '.' + domain
          end
        end

        create_remote_file(master, '/var/simp/environments/production/FakeCA/togen', togen.join("\n"))
        on(master, 'cd /var/simp/environments/production/FakeCA; ./gencerts_nopass.sh')
      end

      # Temporary, partial, hack until we have a good solution to beaker's ssh
      # connection logic problems that started with the commit of
      # https://github.com/voxpupuli/beaker/pull/1586. The 'improved' beaker
      # logic in lib/beaker/ssh_connection.rb treats ssh connection timeouts that
      # can happen on a host when long running actions are happening on other nodes
      # as failures on the disconnected host. Previously, it would attempt to
      # reconnect to perform the action requested on the host and, upon success,
      # move on.
      #
      # All this method provides is a mechanism to work around a ssh connection
      # failure *before* you run a command. So, place it in parts of the code
      # where you have long running segments happening. It doesn't help if
      # the ssh connection failure happens in the **middle** of a long-running
      # segment.
      def ensure_ssh_connection(host, reconnect_attempts = 3)
        tries = reconnect_attempts
        begin
          on(host, 'uptime')
        rescue Beaker::Host::CommandFailure => e
          if e.message.include?('connection failure') && (tries > 0)
            puts "Retrying due to << #{e.message.strip} >>"
            tries -= 1
            retry
          else
            raise e
          end
        end
      end

    end
  end
end
