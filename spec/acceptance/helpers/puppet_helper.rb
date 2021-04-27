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

      # @return the puppetserver status command to be executed on the
      #   puppetserver
      #
      # When the command succeeds on the puppetserver node, the
      # puppetserver is up and accepting connections.
      def puppetserver_status_command(master_fqdn)
        [
          'curl -sSk',
          "--cert /etc/puppetlabs/puppet/ssl/certs/#{master_fqdn}.pem",
          "--key /etc/puppetlabs/puppet/ssl/private_keys/#{master_fqdn}.pem",
          "https://localhost:8140/production/certificate_revocation_list/ca",
          '| grep CRL'
        ].join(' ')
      end

    end
  end
end

