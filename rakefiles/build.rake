#!/usr/bin/rake -T

require 'simp/rake'
include Simp::Rake
class SIMPBuildException < Exception
end

namespace :build do
  desc <<-EOM
  Run bundle at every level of the project.

  This taks runs 'bundle' at each level of the Git subproject tree as well as the top level.

  The intent is to ensure that the entire development space is up to date when starting work.

  Arguments:
    * :action => The action that you with bundle to take. Default => 'install'
    * :verbose => Enable verbose reporting. Default => 'false'
  EOM

  task :bundle, [:action, :verbose, :method] do |t, args|
    args.with_defaults(:action => 'install')
    args.with_defaults(:verbose => 'false')
    args.with_defaults(:method => 'tracking')

    verbose = args.verbose == 'false' ? false : true

    # Grab all currently tracked submodules.
    fake_lp = FakeLibrarian.new("Puppetfile.#{args[:method]}")
    $modules     = fake_lp.modules
    mod_list =  []
    fake_lp.each_module do |environment,name, path|
        if Dir.exists?(path)
            mod_list.push(path)
        end
    end

    failed_mods = Parallel.map(
      mod_list,
      :in_processes => 1,
      :progress => t.name
    ) do |mod|

      status = true
      next unless File.exists?(File.join(mod,'Gemfile'))
      puts "\n#{mod}\n" if verbose
      Dir.chdir(mod) do
        if File.exist?('Gemfile.lock')
          puts "Cleaning Gemfile.lock from #{mod}" if verbose
          rm('Gemfile.lock')
        end
        # Any ruby code that opens a subshell will automatically use the current Bundler environment.
        # Clean env will give bundler the environment present before Bundler is activated.
        Bundler.with_clean_env do
          out = %x(bundle #{args.action} 2>&1)
          status = $?.success?
          puts out if verbose
        end
        mod unless status
      end
    end

    failed_mods.compact!
    warn %(The following modules failed bundle #{args.action}:\n  * #{failed_mods.sort.join("\n  *")})
  end

  namespace :yum do
    @base_dir = File.join(BUILD_DIR,'yum_data')
    @build_arch = 'x86_64'

    ##############################################################################
    # Helpers
    ##############################################################################

    # This is a complete hack to get around the fact that yumdownloader doesn't
    # cache properly when setting TMPDIR.
    def clean_yumdownloader_cache_dir
      require 'etc'

      tmp_dir = '/tmp'
      tmp_dir = ENV['TMPDIR'] if ENV['TMPDIR']

      Dir.glob("#{tmp_dir}/yum-#{Etc.getlogin}-*").each do |cache_dir|
        cache_dir = File.expand_path(cache_dir)

        puts "Cleaning Yumdownloader Cache Dir '#{cache_dir}'"
        begin
          rm_rf(cache_dir)
        rescue Exception => e
          puts "Could not remove cache Dir: #{e}"
        end
      end
    end

    # Return the target directory
    # Expects one argument wich is the 'arguments' hash to one of the tasks.
    def get_target_dir(args)
      fail("Error: You must specify 'os'") unless args.os
      fail("Error: You must specify 'os_version'") unless args.os_version
      fail("Error: You must specify both major and minor version for the OS") unless args.os_version =~ /^.+\..+$/
      fail("Error: You must specify 'simp_version'") unless args.simp_version
      fail("Error: You must specify 'arch'") unless args.arch

      # Yes, this is a kluge but the amount of variable passing that would need
      # to be done to support this is silly.
      @build_arch = args.arch

      return File.join(
        @base_dir,
        "SIMP#{args.simp_version}_#{args.os}#{args.os_version}_#{args.arch}"
      )
    end

    # Return where YUM finds the passed RPM
    def get_rpm_source(rpm,yum_conf)
      # Do we have what we need?

      unless @have_yumdownloader
        %x(yumdownloader --version > /dev/null 2>&1)

        if $?.exitstatus == 127
          fail("Error: Could not find 'yumdownloader'. Please install it and try again.")
        end
        @have_yumdownloader = true
      end

      source = nil

      puts("Looking up: #{rpm}")
      sources = %x(yumdownloader -c #{yum_conf} --urls #{File.basename(rpm,'.rpm')} 2>/dev/null )

      unless $?.success?
        raise(SIMPBuildException,"Could not find a download source")
      end

      sources = sources.split("\n").grep(%r(\.rpm$))

      if sources.empty?
        raise(SIMPBuildException,'No Sources found')
      else
        native_sources = sources.grep(%r((#{@build_arch}|noarch)\.rpm$))

        # One entry, one success
        if native_sources.size == 1
          source = native_sources.first
        # More than one entry is no good.
        elsif native_sources.size > 1
          raise(SIMPBuildException,'More than one file found')
        # The only entry found was for a non-native architecure
        # This means that someone specified the arch explicitly at the
        # command line and we should take it.
        else
          source = sources.first
        end
      end

      return source
    end

    # Snag an RPM via YUM.
    # Returns where the tool got the file from.
    #
    # If passed a source, simply downloads the file into the packages directory
    def download_rpm(rpm, yum_conf, source=nil, distro_dir=Dir.pwd)
      # We're doing this so that we can be 100% sure that we're pulling the RPM
      # from where the last command indicated. YUM can choose multiple sources
      # and we definitely want the one that we actually state!
      source = get_rpm_source(rpm,yum_conf) unless source

      Dir.chdir('packages') do
        full_pkg = source.split('/').last
        unless File.exist?(full_pkg)
          puts("Downloading: #{full_pkg}")
          %x(curl -L --max-redirs 10 -s -o "#{full_pkg}" -k "#{source}")

          unless $?.success?
            raise(SIMPBuildException,"Could not download")
          end

          begin
            validate_rpm(full_pkg)
          rescue SIMPBuildException
            rm(full_pkg) if File.exist?(full_pkg)
            raise(SIMPBuildException,"#{rpm} could not be downloaded")
          end
        end
      end

      return source
    end

    # Check to see if an RPM is actually a valid RPM
    # Optionally remove any invalid RPMS.
    #
    # Returns true if the rm is valid raises a SIMPBuildException otherwise
    def validate_rpm(rpm, clean=true)
      # Check to see if what we got is actually valid
      %x(rpm -K --nosignature "#{rpm}" 2>&1 > /dev/null)

      unless $?.success?
        errmsg = "RPM '#{rpm}' is invalid"

        if clean
          errmsg += ', removing'
          FileUtils.rm(rpm)
        end

        raise(SIMPBuildException,errmsg)
      end

      true
    end

    # Create the YUM config file
    #  * yum_tmp => The directory in which to store the YUM DB and any other
    #  temporary files.
    #
    #  Returns the location of the YUM Configuration
    def generate_yum_conf(distro_dir=Dir.pwd)
      yum_conf_template = <<-EOM.gsub(/^\s+/,'')
      [main]
      keepcache = 1
      persistdir = <%= yum_cache %>
      logfile = <%= yum_logfile %>
      exactarch = 1
      obsoletes = 0
      gpgcheck = 1
      plugins = 1
      reposdir = <%= repo_dirs.join(' ') %>
      assumeyes = 1
      EOM

      yum_conf = nil
      Dir.chdir(distro_dir) do
        # Create the target directory
        yum_tmp = File.join('packages','yum_tmp')
        mkdir_p(yum_tmp) unless File.directory?(yum_tmp)

        yum_cache = File.expand_path(File.join(yum_tmp,'yum_cache'))
        mkdir_p(yum_cache) unless File.directory?(yum_cache)

        yum_logfile = File.expand_path(File.join(yum_tmp,'yum.log'))

        repo_dirs = []
        # Add the global directory
        repo_dirs << File.expand_path('../my_repos')
        if File.directory?('my_repos')
          # Add the local user repos if they exist
          repo_dirs << File.expand_path('my_repos')
        else
          # Add the default Internet repos otherwise
          repo_dirs << File.expand_path('repos')
        end

        # Create our YUM config file
        yum_conf = File.join(yum_tmp,'yum.conf')
        File.open(yum_conf,'w') do |fh|
          fh.write(ERB.new(yum_conf_template,nil,'-').result(binding))
        end
      end

      return yum_conf
    end

    def get_known_packages(target_dir=Dir.pwd)
      known_package_hash = {}

      Dir.chdir(target_dir) do
        if File.exist?('packages.yaml')
          known_package_hash = YAML::load_file('packages.yaml')
        end
      end

      unless known_package_hash.empty?
        unless known_package_hash.first.last[:rpm_name]
          # Convert from Legacy
          # This is imperfect since we can't accurately determine the RPM sort
          # name but the code should straighten everything out since we rewrite
          # the entire file based on what has been downloaded.
          new_package_hash = known_package_hash.dup

          known_package_hash.each_key { |k|
            new_package_hash[k][:rpm_name] = k
          }

          known_package_hash = new_package_hash
        end
      end

      return known_package_hash
    end

    def get_downloaded_packages(target_dir=Dir.pwd)
      downloaded_packages = {}

      Dir.chdir(target_dir) do
        Dir.glob('packages/*.rpm').each do |pkg|
          downloaded_packages[Simp::RPM.get_info(pkg)[:name]] = { :rpm_name => File.basename(pkg) }
        end
      end

      return downloaded_packages
    end

    # Update the packages.yaml and packages/ directories
    #   * target_dir => The actual distribution directory where packages.yaml and
    #                   packages/ reside.
    def update_packages(target_dir,bootstrap=false)
      # This really should never happen....
      unless File.directory?(target_dir)
        fail <<-EOM
  Error: Could not update packages.

  Target directory '#{target_dir}' does not exist!
        EOM
      end

      Dir.chdir(target_dir) do
        unless File.exist?('packages.yaml') || File.directory?('packages')
          fail <<-EOM
  Error: Either 'pacakges.yaml' or the 'packages/' directory need to exist under '#{target_dir}
          EOM
        end

        yum_conf = generate_yum_conf

        known_package_hash = get_known_packages
        downloaded_package_hash = get_downloaded_packages

        # This holds packages for which we could not find a source.
        unknown_package_hash = {}

        known_packages = known_package_hash.keys.collect{ |pkg|
          pkg = known_package_hash[pkg][:rpm_name]
        }.compact

        downloaded_packages = downloaded_package_hash.keys.collect{ |pkg|
          pkg = downloaded_package_hash[pkg][:rpm_name]
        }.compact

        if known_packages.empty? && downloaded_packages.empty?
          fail <<-EOM
  Error: Could not find anything to do!

  In #{target_dir}:
      No packages in either packages.yaml or the packages/ directory
          EOM
        end

        failed_updates = {}

        # Kill any pre-existing invalid packages that might be hanging around
        downloaded_packages.dup.each do |package|
          begin
            validate_rpm(%(packages/#{package}))
          rescue SIMPBuildException => e
            rm(%(packages/#{package})) if File.exist?(%(packages/#{package}))
            downloaded_packages.delete(package)
            failed_updates[package] = e
          end
        end

        # Let's go ahead and grab everything that we know the source for
        (known_packages - downloaded_packages).sort.each do |package_to_download|
          begin
            # Do we have a valid external source?
            package_source = known_package_hash.find{|k,h| h[:rpm_name] == package_to_download}.last[:source]
            if package_source && (package_source =~ %r(^[a-z]+://))
              download_rpm(package_to_download,yum_conf,package_source)
            else
              # If you get here, then you'll need to have an internal mirror of the
              # repositories in question. This covers things like private RPMs as
              # well as Commercial RPMs from Red Hat.
              download_rpm(package_to_download,yum_conf)
            end
          rescue SIMPBuildException => e
            base_package_name = known_package_hash.find{|k,h| h[:rpm_name] == package_to_download}.first
            updated_package = update_rpm(base_package_name,yum_conf,true)

            if updated_package
              updated_package_rpm_name = updated_package[base_package_name][:rpm_name]

              # We just got a new one! Replace the old one.
              puts "Updating: #{package_to_download} with #{updated_package_rpm_name}"

              # We now know about this
              downloaded_packages.delete(package_to_download)
              downloaded_package_hash.merge!(updated_package)
              known_package_hash.merge!(updated_package)
              known_packages << updated_package_rpm_name
            else
              failed_updates[package_to_download] = e
            end
          end
        end

        # Now, let's update the known_packages data structure for anything that's
        # new!
        (downloaded_packages - known_packages).each do |package|
          downloaded_package_hash.keys.each do |key|
            if downloaded_package_hash[key][:rpm_name] == package
              begin
                rpm_source = get_rpm_source(package,yum_conf)
                known_package_hash[key] = downloaded_package_hash[key]
                known_package_hash[key][:source] = rpm_source
              rescue SIMPBuildException => e
                unknown_package_hash[key] = {} unless unknown_package_hash[key]
                unknown_package_hash[key][:rpm_name] = package
                failed_updates[package] = e
              end
              break
            end
          end
        end

        # OK! In theory, we're done with all of this nonsense! Let's update the
        # YAML file.
        File.open('packages.yaml','w') do |fh|
          sorted_packages = {}
          known_package_hash.keys.sort.each do |k|
            # Make sure we don't capture any legacy malformed info
            if known_package_hash[k][:rpm_name][-4..-1] == '.rpm'
              sorted_packages[k] = known_package_hash[k]
            end
          end
          fh.puts(sorted_packages.to_yaml)
        end

        if unknown_package_hash.empty?
          rm('unknown_packages.yaml') if File.exist?('unknown_packages.yaml')
        else
          # Next, let's freshen up the unknown packages reference file
          File.open('unknown_packages.yaml','w') do |fh|
            sorted_packages = {}
            unknown_package_hash.keys.sort.each do |k|
              sorted_packages[k] = unknown_package_hash[k]
            end
            fh.puts(sorted_packages.to_yaml)
          end
        end

        # Now, let's tell the user what went wrong.
        unless failed_updates.empty?
          $stderr.puts("Warning: There were errors updating some files:")

          failed_updates.keys.sort.each do |k|
            $stderr.puts("  * #{k} => #{failed_updates[k]}")
          end
        end
      end
    end

    # Downloads a packge into the *current working directory*
    #
    # Will create a directory called 'obsolete' and move any old packages into
    # that location if a newer one is found.
    #
    # Arguments:
    #   * pkg     => The name of the package to download. YUM supported globs
    #                are allowed.
    #   * verbose => If true, identify potential actions of note.
    #
    # Returns a hash of the new package information if found.
    #
    def update_rpm(pkg,yum_conf,verbose=false)
      updated_pkg = nil

      begin
        new_pkg_source = download_rpm(pkg, yum_conf)
        new_pkg = new_pkg_source.split('/').last

        Dir.chdir('packages') do
          new_pkg_info = Simp::RPM.new(new_pkg)

          # Find any old packages and move them into the 'obsolete' directory.
          Dir.glob("#{new_pkg_info.basename}*.rpm").each do |old_pkg|
            old_pkg_info = Simp::RPM.new(old_pkg)
            # Don't obsolete yourself!
            next unless new_pkg_info.basename == old_pkg_info.basename

            %x(rpmdev-vercmp #{new_pkg_info.full_version} #{old_pkg_info.full_version})
            exit_status = $?.exitstatus
            if exit_status == 11
              mkdir('obsolete') unless File.directory?('obsolete')

              puts("Retiring #{old_pkg}") if verbose

              mv(old_pkg,'obsolete')
            end
          end

          updated_pkg = {
            new_pkg_info.basename => {
              :source => new_pkg_source,
              :rpm_name => new_pkg
            }
          }
        end
      rescue SIMPBuildException => e
        puts("Failed to update #{pkg} -> #{e}") if verbose
      end

      updated_pkg
    end

    ##############################################################################
    # Main tasks
    ##############################################################################

    desc <<-EOM
    Create a workspace for a new distribution.

    Creates a YUM scaffold under
    #{BUILD_DIR}/yum_data/SIMP{:simp_version}_{:os}{:os_version}_{:arch}.

    * :os           - The Operating System that you wish to use.
                      Supported OSs: #{TARGET_DISTS}.join(', ')
    * :os_version   - The Major and Minor version of the OS. Ex: 6.6, 7.0, etc...
    * :simp_version - The Full version of SIMP that you are going to support. Do
                      not enter the revision number. Ex: 5.1.0, 4.2.0.
                      Default: Auto

    * :arch         - The architecture that you support. Default: x86_64
    EOM
    task :scaffold,[:os,:os_version,:simp_version,:arch] do |t,args|
      # SIMP_VERSION is set in the main Rakefile
      args.with_defaults(:simp_version => SIMP_VERSION.split('-').first)
      args.with_defaults(:arch => @build_arch)

      target_dir = get_target_dir(args)

      unless File.exist?(target_dir)
        mkdir_p(target_dir)
        puts("Created #{target_dir}")
      end

      # Put together the rest of the scaffold directories
      Dir.chdir(@base_dir) do
        mkdir('my_repos') unless File.exist?('my_repos')
      end

      Dir.chdir(target_dir) do
        mkdir('repos') unless File.exist?('repos')
        mkdir('packages') unless File.exist?('packages')
      end
    end

    desc <<-EOM
    Download ALL THE PACKAGES.

    Downloads everything as appropriate for the distribution at
    #{BUILD_DIR}/yum_data/SIMP{:simp_version}_{:os}{:os_version}_{:arch}.

    * :os           - The Operating System that you wish to use.
                      Supported OSs: #{TARGET_DISTS}.join(', ')
    * :os_version   - The Major and Minor version of the OS. Ex: 6.6, 7.0, etc...
    * :simp_version - The Full version of SIMP that you are going to support. Do
                      not enter the revision number. Ex: 5.1.0, 4.2.0.
                      Default: Auto

    * :arch         - The architecture that you support. Default: x86_64
    EOM
    task :sync,[:os,:os_version,:simp_version,:arch] => [:scaffold] do |t,args|
      # SIMP_VERSION is set in the main Rakefile
      args.with_defaults(:simp_version => SIMP_VERSION.split('-').first)
      args.with_defaults(:arch => @build_arch)

      target_dir = get_target_dir(args)

      update_packages(target_dir)
    end

    desc <<-EOM
    Display the difference between record and download.

    Provides a list of the differences between what we have recorded in
    'packages.yaml' and the downloads in the 'packages' directory.

    * :os           - The Operating System that you wish to use.
                      Supported OSs: #{TARGET_DISTS}.join(', ')
    * :os_version   - The Major and Minor version of the OS. Ex: 6.6, 7.0, etc...
    * :simp_version - The Full version of SIMP that you are going to support. Do
                      not enter the revision number. Ex: 5.1.0, 4.2.0.
                      Default: Auto

    * :arch         - The architecture that you support. Default: x86_64
    EOM
    task :diff,[:os,:os_version,:simp_version,:arch] => [:scaffold] do |t,args|
      args.with_defaults(:simp_version => SIMP_VERSION.split('-').first)
      args.with_defaults(:arch => @build_arch)

      differences_found = false

      target_dir = get_target_dir(args)

      known_package_hash = get_known_packages(target_dir)
      downloaded_package_hash = get_downloaded_packages(target_dir)

      known_packages = known_package_hash.keys.compact
      downloaded_packages = downloaded_package_hash.keys.compact

      known_not_downloaded = (known_packages - downloaded_packages).sort
      unless known_not_downloaded.empty?
        differences_found = true

        puts("=== Packages Not Downloaded ===")
        known_not_downloaded.each do |package|
          puts "  - #{package}"
        end
      end

      downloaded_not_known = (downloaded_packages - known_packages).sort
      unless downloaded_not_known.empty?
        differences_found = true

        puts ("=== Pacakges Downloaded not Recorded ===")
        downloaded_not_known.each do |package|
          puts "  ~ #{downloaded_package_hash[package][:rpm_name]}"
        end
      end

      if differences_found
        exit 1
      else
        puts("=== No Differences Found ===")
        exit 0
      end
    end

    desc <<-EOM
    Download an RPM for the given distribution.

    Fetches the *latest* version of an RPM from the included sources and places
    it in the downloads directory.

    Any old versions are moved into an 'obsolete' directory.

    This does *not* update the packages.yaml file.

    Note: for convienience, you can specify the output of yum_diff as your input
          package and it will try to pull down everything in the file.
          * If you do this, it must be the *full path* to the file.

    * :pkg          - The package that you wish to download.
    * :os           - The Operating System that you wish to use.
                      Supported OSs: #{TARGET_DISTS}.join(', ')
    * :os_version   - The Major and Minor version of the OS. Ex: 6.6, 7.0, etc...
    * :simp_version - The Full version of SIMP that you are going to support. Do
                      not enter the revision number. Ex: 5.1.0, 4.2.0.
                      Default: Auto

    * :arch         - The architecture that you support. Default: x86_64
    EOM
    task :fetch,[:pkg,:os,:os_version,:simp_version,:arch] => [:scaffold] do |t,args|
      args.with_defaults(:simp_version => SIMP_VERSION.split('-').first)
      args.with_defaults(:arch => @build_arch)

      fail("Error: You must specify 'pkg'") unless args.pkg

      pkgs = []
      # Handle the output of build:yum_diff
      if File.readable?(args.pkg)
        File.read(args.pkg).each_line do |line|
          if line =~ /\s+~\s+(.*)/
            pkgs << $1.split(/-\d+/).first
          end
        end
      else
        # Handle the default case
        pkgs = [args.pkg]
      end

      Dir.chdir(get_target_dir(args)) do
        pkgs.each do |pkg|
          # Pull down the RPM
          update_rpm(pkg,generate_yum_conf,true)
        end
      end
    end

    desc <<-EOM
    Clean the Yumdownloader cache.

    Use this if you're having strange issues fetching packages.
    EOM
    task :clean_cache do
        clean_yumdownloader_cache_dir
    end
  end
end
