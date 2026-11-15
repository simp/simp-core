module Acceptance
  module Helpers
    module PuppetHelper

      # The simp-core Puppetfile the suites install from
      #
      # Set BEAKER_puppetfile to 'pinned' (default), 'branches', or the path
      # of any Puppetfile laid out like Puppetfile.pinned.
      def simp_core_puppetfile
        name = ENV.fetch('BEAKER_puppetfile', '').strip
        case name
        when '', 'pinned' then 'Puppetfile.pinned'
        when 'branches' then 'Puppetfile.branches'
        else name
        end
      end

      # Parses BEAKER_puppetfile_overrides
      #
      # Entries are separated by whitespace or commas and take the form
      #   <module name>=<git URL>#<ref>
      # e.g.
      #   simp-ssh=https://github.com/someone/pupmod-simp-ssh#my-branch
      #
      # The ref may be a branch, tag or commit. An entry whose name is not in
      # the Puppetfile is added to the Puppet modules.
      #
      # @return [Hash] module name => { git:, ref: }
      def puppetfile_overrides
        ENV.fetch('BEAKER_puppetfile_overrides', '').split(%r{[\s,]+}).reject(&:empty?).to_h do |entry|
          match = entry.match(%r{\A([^=\s]+)=(\S+)#([^#\s]+)\z})
          raise "Invalid BEAKER_puppetfile_overrides entry '#{entry}'; expected <name>=<git url>#<ref>" unless match

          [match[1], { git: match[2], ref: match[3] }]
        end
      end

      # Create a Puppetfile for r10K from the specified 'moduledir' path
      # of a simp-core Puppetfile, with BEAKER_puppetfile_overrides applied.
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
        content = r10k_puppetfile.join  # each line already contains a \n

        all_names = lines.grep(%r{^mod\s}).map { |l| l[%r{^mod\s+['"]([^'"]+)['"]}, 1] }
        puppetfile_overrides.each do |name, source|
          entry = "mod '#{name}',\n  :git => '#{source[:git]}',\n  :ref => '#{source[:ref]}'\n"
          block = %r{^mod\s+['"]#{Regexp.escape(name)}['"],?\s*\n(?:[ \t]+:.*\n?)*}
          if content.match?(block)
            content = content.sub(block, entry)
          elsif !all_names.include?(name) && moduledir_path == 'src/puppet/modules'
            content += "\n#{entry}"
          else
            next
          end
          puts "Puppetfile override (#{moduledir_path}): #{name} => #{source[:git]} #{source[:ref]}"
        end
        content
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

      # Install the Puppet/OpenVox agent from the collection's release repo
      # (a specific version if PUPPET_VERSION is set)
      def install_puppet_agent(host)
        puppet_collection = puppet_collection_for(host)
        gem_name = puppet_collection.sub(%r{\d+.*\z}, '') # 'openvox' or 'puppet'
        package_name = (gem_name == 'openvox') ? 'openvox-agent' : 'puppet-agent'

        puppet_version = latest_puppet_agent_version_for(ENV['PUPPET_VERSION'], gem_name)
        host.install_package(package_name, '', puppet_version)
      end

      # Install the Puppet/OpenVox server RPM on a host, working around
      # legacy puppetserver RPM digest issues, if necessary
      def install_puppetserver(host)
        puppet_collection = puppet_collection_for(host)
        package_name = puppet_collection.start_with?('openvox') ? 'openvox-server' : 'puppetserver'

        if ( package_name == 'puppetserver' ) &&
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
          host.install_package(package_name)
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

