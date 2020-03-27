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
        if File.exists?(repo_filename)
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
          puppet_collection = ENV['PUPPET_COLLECTION'] || 'puppet5'

          puts('='*72)
          puts("Using Puppet #{puppet_collection} repo from yum.puppetlabs.com")
          puts('='*72)

          if host.host_hash[:platform] =~ /el-8/
            family = 'el-8'
          elsif host.host_hash[:platform] =~ /el-7/
            family = 'el-7'
          elsif host.host_hash[:platform] =~ /el-6/
            family = 'el-6'
          else
            fail("install_puppet_repo(): Cannot determine puppet repo for #{host.name}")
          end
          url = "http://yum.puppetlabs.com/#{puppet_collection}/#{puppet_collection}-release-#{family}.noarch.rpm"
          on(host, "yum install #{url} -y")
        end
      end

      # Install a SIMP packagecloud yum repo
      #
      # - Each repo is modeled after what appears in simp-doc
      # - See https://packagecloud.io/simp-project/ for the reponame key
      #
      # +host+: Host object on which SIMP repo(s) will be installed
      # +reponame+: The base name of the repo, e.g. '6_X'
      # +type+: Which repo to install:
      #   :main for the main repo containing SIMP puppet modules
      #   :deps for the SIMP dependency repo containing OS or application
      #         RPMs not available from standard CentOS repos
      #
      # @fails if the specified repo cannot be installed on host
      def install_internet_simp_repo(host, reponame, type)
        case type
        when :main
          full_reponame = reponame
          # FIXME: Use a gpgkey list appropriate for more than 6_X
          repo = <<~EOM
            [simp-project_#{reponame}]
            name=simp-project_#{reponame}
            baseurl=https://packagecloud.io/simp-project/#{reponame}/el/$releasever/$basearch
            gpgcheck=1
            enabled=1
            gpgkey=https://raw.githubusercontent.com/NationalSecurityAgency/SIMP/master/GPGKEYS/RPM-GPG-KEY-SIMP
                   https://download.simp-project.com/simp/GPGKEYS/RPM-GPG-KEY-SIMP-6
            sslverify=1
            sslcacert=/etc/pki/tls/certs/ca-bundle.crt
            metadata_expire=300
          EOM
        when :deps
          full_reponame = "#{reponame}_Dependencies"
          # FIXME: Use a gpgkey list appropriate for more than 6_X
          repo = <<~EOM
            [simp-project_#{reponame}_dependencies]
            name=simp-project_#{reponame}_dependencies
            baseurl=https://packagecloud.io/simp-project/#{reponame}_Dependencies/el/$releasever/$basearch
            gpgcheck=1
            enabled=1
            gpgkey=https://raw.githubusercontent.com/NationalSecurityAgency/SIMP/master/GPGKEYS/RPM-GPG-KEY-SIMP
                   https://download.simp-project.com/simp/GPGKEYS/RPM-GPG-KEY-SIMP-6
                   https://yum.puppet.com/RPM-GPG-KEY-puppetlabs
                   https://yum.puppet.com/RPM-GPG-KEY-puppet
                   https://apt.postgresql.org/pub/repos/yum/RPM-GPG-KEY-PGDG-96
                   https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-$releasever
            sslverify=1
            sslcacert=/etc/pki/tls/certs/ca-bundle.crt
            metadata_expire=300
          EOM
          full_reponame = "#{reponame}_Dependencies"
        else
          fail("install_internet_simp_repo() Unknown repo type specified '#{type.to_s}'")
        end
        puts('='*72)
        puts("Using SIMP #{full_reponame} Internet repo from packagecloud")
        puts('='*72)

        create_remote_file(host, "/etc/yum.repos.d/simp-project_#{full_reponame.downcase}.repo", repo)
      end

      # Set up SIMP repos on the host
      #
      # By default, the SIMP '6_X' repos available from packagecloud
      # will be configured.  This can be overidden with the BEAKER_repo
      # environment variable as follows:
      # - When set to a fully qualified path of a repo file, the file will
      #   be installed as a repo on the host.  In this case set_up_simp_main
      #   and set_up_simp_deps are both ignored, as the repo file is assumed
      #   to be configured appropriately.
      # - Otherwise, BEAKER_repo is assumed to be the base name of the SIMP
      #   internet repos (e.g., '6_X_Alpha')
      #
      # +host+: Host object on which SIMP repo(s) will be installed
      # +set_up_simp_main+:  Whether to set up the main SIMP repo
      # +set_up_simp_deps+:  Whether to set up the SIMP dependencies repo
      #
      # @fails if the specified repos cannot be installed on host
      def set_up_simp_repos(host, set_up_simp_main = true, set_up_simp_deps = true )
        reponame = ENV['BEAKER_repo']
        reponame ||= '6_X'
        if reponame[0] == '/'
          copy_repo(host, reponame)
        else
          install_internet_simp_repo(host, reponame, :main) if set_up_simp_main
          install_internet_simp_repo(host, reponame, :deps) if set_up_simp_deps
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
          Dir.exists?("spec/fixtures") || Dir.mkdir("spec/fixtures")
          File.write("spec/fixtures/#{filename}", Net::HTTP.get(URI.parse(url)))
          tarball = "spec/fixtures/#{filename}"
          puts("Downloaded SIMP release tarball from #{url} to #{tarball}")
        else
          unless tarball.nil?
            if File.exists?(tarball)
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
