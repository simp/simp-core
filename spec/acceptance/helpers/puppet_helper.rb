module Acceptance
  module Helpers
    module PuppetHelper

      # Create a Puppetfile for r10K from the specified 'moduledir' path
      # of a simp-core Puppetfile.
      # Returns Puppetfile content
      def create_r10k_puppetfile(simp_core_puppetfile, moduledir_path)
        r10k_puppetfile = []
        lines = IO.readlines(simp_core_puppetfile)
        moduledir_section = false
        lines.each do |line|
           if line.match(/^moduledir/)
             if line.match(/^moduledir '#{Regexp.escape(moduledir_path)}'/)
               moduledir_section = true
             else
               moduledir_section = false
             end
             next
           end
           r10k_puppetfile << line if moduledir_section
        end
        r10k_puppetfile.join  # each line already contains a \n
      end

      # Enables autosign for any host in the domain on the puppetserver
      #
      # TODO:  pass in a array of Hosts (objects) and add each one
      # to the autosign.conf, in lieu of this lazy *.<domain>
      # configuration
      def enable_puppet_autosign(server, domain)
        result = on(server, 'puppet config print --section server autosign')
        autosign_file = result.stdout.strip
        on(server, "echo '*.#{domain}' >> #{autosign_file}")
        on(server, "chmod 644 #{autosign_file}")
        on(server, "grep #{domain} #{autosign_file}")
      end

      # Install puppetmaster RPM on a host, working around puppetserver
      # RPM digest issues, if necessary
      def install_puppetserver(host)
        os_maj = fact_on(host, 'operatingsystemmajrelease').to_i
        if ( os_maj > 7) &&
           ( on(host, 'cat /proc/sys/crypto/fips_enabled', :accept_all_exit_codes => true).stdout.strip == '1' )
          # Workaround until the puppetserver RPM digest problem on EL8 in FIPS
          # mode is solved (https://tickets.puppetlabs.com/browse/PUP-10859)
          # **or** SIMP repackages the puppetserver RPM (SIMP-10434)

          # Change to the following when it works for all RHEL-like OSs
          # if host.fips_mode?
          host.install_package('yum-utils')
          host.install_package('java-headless')
          on(host, 'yumdownloader puppetserver')
          on(host, 'rpm -i --force --nodigest --nofiledigest puppetserver*.rpm')
        else
          host.install_package('puppetserver')
        end
      end

      # @return the puppetserver status command to be executed on the
      #   puppetserver
      #
      # When the command succeeds on the puppetserver node, the
      # puppetserver is up and accepting connections.
      def puppetserver_status_command(server_fqdn)
        [
          'curl -sSk',
          "--cert /etc/puppetlabs/puppet/ssl/certs/#{server_fqdn}.pem",
          "--key /etc/puppetlabs/puppet/ssl/private_keys/#{server_fqdn}.pem",
          '-o /dev/null',
          '-w "%{http_code}\n"',
          'https://localhost:8140/status/v1/services',
          '| grep -qe 200'
        ].join(' ')
      end

      # Sets the contents of the default.yaml file for the specified Puppet
      # environment
      #
      # - **Assumes** default.yaml file already exists with correct permissions
      # - Overwrites existing contents
      # - Logs new contents for debugging
      #
      # @param server Puppet server Host
      # @param hiera  Hash of hieradata to be persisted in the default.yaml file
      # @param puppet_env Puppet environment
      #
      def set_default_yaml(server, hiera, puppet_env = 'production')
        default_yaml_filename = "/etc/puppetlabs/code/environments/#{puppet_env}/data/default.yaml"
        create_remote_file(server, default_yaml_filename, hiera.to_yaml)
        on(server, "cat #{default_yaml_filename}")
      end
    end
  end
end

