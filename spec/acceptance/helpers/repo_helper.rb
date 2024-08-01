module Acceptance
  module Helpers
    module RepoHelper

      # Install a yum repo
      #
      # +host+: Host object on which the yum repo will be installed
      # +repo_filename+: Path of the repo file to be installed
      #
      # @fails if the specified repo file cannot be installed on host
      def copy_repo(host, repo_filename, repo_name = 'simp_manual.repo')
        if File.exist?(repo_filename)
          puts('='*72)
          puts("Using repos defined in #{repo_filename}")
          puts('='*72)
          scp_to(host, repo_filename, "/etc/yum.repos.d/#{repo_name}")
        else
          fail("File #{repo_filename} could not be found")
        end
      end

      def install_puppet_repo(host)
        case ENV['BEAKER_puppet_repo']
        when 'true'
           install_repo = true
        when 'false'
           install_repo = false
        else
           install_repo = true
        end

        if install_repo
          puppet_collection = ENV['BEAKER_PUPPET_COLLECTION'] || 'puppet6'

          puts('='*72)
          puts("Using Puppet #{puppet_collection} repo from yum.puppetlabs.com")
          puts('='*72)

          if host.host_hash[:platform] =~ /(el-[78])/
            family = $1
          else
            fail("install_puppet_repo(): No supported OS platform found for #{host.name}; unable to determine puppet repo")
          end
          url = "http://yum.puppetlabs.com/#{puppet_collection}/#{puppet_collection}-release-#{family}.noarch.rpm"
          on(host, "yum install #{url} -y")
        end
      end

      # Set up SIMP repos on the host
      #
      # By default, the SIMP '6' repos will be configured.  This can be
      # overidden with the BEAKER_repo environment variable as follows:
      # - When set to a fully qualified path of a repo file, the file will
      #   be installed as a repo on the host.  In this case set_up_simp_main
      #   and set_up_simp_deps are both ignored, as the repo file is assumed
      #   to be configured appropriately.
      # - Otherwise, BEAKER_repo should take the form
      # `<simprelease>[,<simpreleasetype>]`. For instance, if you want to use
      # release 6 from the unstable repos, you would pass
      # `BEAKER_repo="6,unstable"`
      #
      # +host+: Host object on which SIMP repo(s) will be installed
      # +set_up_simp_main+:  Whether to set up the main SIMP repo
      # +set_up_simp_deps+:  Whether to set up the SIMP dependencies repos
      #
      # @fails if the specified repos cannot be installed on host
      def set_up_simp_repos(host, set_up_simp_main = true, set_up_simp_deps = true )
        reponame = ENV['BEAKER_repo']

        if reponame && reponame[0] == '/'
          copy_repo(host, reponame)
        else
          disable_list = []
          unless set_up_simp_main
            disable_list << 'simp-community-simp'
          end

          if set_up_simp_deps
            os_maj = fact_on(host, 'operatingsystemmajrelease').to_i
            if os_maj > 7
              # FIXME For Puppet 6, can't access the simp-community-postgresql
              # non-modular repo that contains postgresql 9.6, unless we first
              # disable the AppStream postgresql repo. Need to figure out if
              # this must also be done for Puppet 7, which uses postgresql 11.
              on(host, 'dnf module disable postgresql -y')
            end
          else
            disable_list << 'simp-community-epel'
            disable_list << 'simp-community-puppet'
            disable_list << 'simp-community-postgresql'
          end

          install_simp_repos(host, disable_list)

          if reponame
            simp_release, simp_releasetype = reponame.split(',')
            create_remote_file(host, '/etc/yum/vars/simprelease', simp_release)
            create_remote_file(host, '/etc/yum/vars/simpreleasetype', simp_releasetype) if simp_releasetype
          end
        end
      end

      # Returns the path to a SIMP release tarball or nil if a tarball
      # cannot be found/downloaded
      #
      # If BEAKER_release_tarball is not specified, finds the release
      # tar.gz file in the build directory of this simp-core checkout
      # for the relver and osname specified, and then returns the path
      # to that file.
      #
      # If BEAKER_release_tarball is specified and is a file, returns
      # that file.
      #
      # If BEAKER_release_tarball is a URL, downloads the file and
      # returns the path to the downloaded file
      #
      # +relver+: SIMP release version
      # +osname+: OS name
      #
      def find_simp_release_tarball(relver, osname)
        tarball = ENV['BEAKER_release_tarball']
        if tarball and tarball.strip.empty?
          tarball = nil
        end

        if tarball.nil?
          tarball = Dir.glob("build/distributions/#{osname}/#{relver}/x86_64/DVD_Overlay/SIMP*.tar.gz")[0]
        end

        if tarball =~ /https/
          filename = "SIMP-downloaded-#{osname}-#{relver}-x86_64.tar.gz"
          url = "#{tarball}"
          require 'net/http'
          Dir.exist?("spec/fixtures") || Dir.mkdir("spec/fixtures")
          File.write("spec/fixtures/#{filename}", Net::HTTP.get(URI.parse(url)))
          tarball = "spec/fixtures/#{filename}"
          puts("Downloaded SIMP release tarball from #{url} to #{tarball}")
        else
          unless tarball.nil?
            if File.exist?(tarball)
              puts("Found SIMP release tarball: #{tarball}")
            else
              warn("SIMP release tarball '#{tarball}' not found")
              tarball = nil
            end
          end
        end
        tarball
      end

      def set_up_tarball_repo(host, tarball)
        puts('='*72)
        puts("Creating local repository on #{host.name} from #{tarball}")
        puts('='*72)
        host.install_package('createrepo')
        scp_to(host, tarball, '/root/')
        tarball_basename = File.basename(tarball)
        on(host, "mkdir -p /var/www && cd /var/www && tar xzf /root/#{tarball_basename}")
        on(host, 'createrepo -q -p /var/www/SIMP/noarch')
        create_remote_file(host, '/etc/yum.repos.d/simp_tarball.repo', <<-EOF.gsub(/^\s+/,'')
          [simp-tarball]
          name=Tarball repo
          baseurl=file:///var/www/SIMP/noarch
          enabled=1
          gpgcheck=0
          repo_gpgcheck=0
          EOF
        )
        on(host, 'yum makecache')
      end
    end
  end
end
