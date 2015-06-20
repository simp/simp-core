#!/usr/bin/rake -T

require 'simp/rake'
include Simp::Rake

class SIMPBuildException < Exception
end

namespace :build do
  @base_dir = File.join(BUILD_DIR,'yum_data')

  ##############################################################################
  # Helpers
  ##############################################################################

  # Return the target directory
  # Expects one argument wich is the 'arguments' hash to one of the tasks.
  def get_target_dir(args)
    fail("Error: You must specify 'os'") unless args.os
    fail("Error: You must specify 'os_version'") unless args.os_version
    fail("Error: You must specify 'simp_version'") unless args.simp_version
    fail("Error: You must specify 'arch'") unless args.arch

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

    puts("Looking up: #{rpm}")
    source = %x(yumdownloader -c #{yum_conf} --urls #{rpm} 2>/dev/null ).split("\n").last
    unless $?.success?
      raise(SIMPBuildException,"Could not find a download source")
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
      puts("Downloading: #{rpm}")
      %x(curl -s -O -k #{source})
      unless $?.success?
       raise(SIMPBuildException,"Could not download")
      end
    end

    return source
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
    known_packages_hash = {}

    Dir.chdir(target_dir) do
      if File.exist?('packages.yaml')
        known_packages_hash = YAML::load_file('packages.yaml')
      end
    end

    return known_packages_hash
  end

  def get_downloaded_packages(target_dir=Dir.pwd)
    downloaded_packages = []

    Dir.chdir(target_dir) do
      downloaded_packages = Dir.glob('packages/*.rpm').map{|x| File.basename(x,'.rpm')}
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

      known_packages_hash = get_known_packages

      known_packages = known_packages_hash.keys
      downloaded_packages = get_downloaded_packages

      if known_packages.empty? && downloaded_packages.empty?
        fail <<-EOM
Error: Could not find anything to do!

In #{target_dir}:
    No packages in either packages.yaml or the packages/ directory
        EOM
      end

      failed_updates = {}

      # Let's go ahead and grab everything that we know the source for first!
      (known_packages - downloaded_packages).each do |package|
        begin
          # Do we have a valid external source?
          if known_packages_hash[package][:source] =~ /^[a-z]+:\/\//
            download_rpm(package,yum_conf,known_packages_hash[package][:source])
          else
            # If you get here, then you'll need to have an internal mirror of the
            # repositories in question. This covers things like private RPMs as
            # well as Commercial RPMs from Red Hat.
            download_rpm(package,yum_conf)
          end
        rescue SIMPBuildException => e
          failed_updates[package] = e
        end
      end

      # Now, let's update the known_packages data structure for anything that's
      # new!
      (downloaded_packages - known_packages).each do |package|
        begin
          known_packages_hash[package] = { :source => get_rpm_source(package,yum_conf) }
        rescue SIMPBuildException => e
          failed_updates[package] = e
        end
      end

      # OK! In theory, we're done with all of this nonsense! Let's update the
      # YAML file.
      File.open('packages.yaml','w') do |fh|
        fh.puts(known_packages_hash.to_yaml)
      end

      # Now, let's tell the user what went wrong.
      unless failed_updates.empty?
        $stderr.puts("Warning: There were errors updating some files:")

        failed_updates.each_pair do |k,v|
          $stderr.puts("  * #{k} => #{v}")
        end
      end
    end
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
  task :yum_scaffold,[:os,:os_version,:simp_version,:arch] do |t,args|
    # SIMP_VERSION is set in the main Rakefile
    args.with_defaults(:simp_version => SIMP_VERSION.split('-').first)
    args.with_defaults(:arch => 'x86_64')

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
  task :yum_sync,[:os,:os_version,:simp_version,:arch] => [:yum_scaffold] do |t,args|
    # SIMP_VERSION is set in the main Rakefile
    args.with_defaults(:simp_version => SIMP_VERSION.split('-').first)
    args.with_defaults(:arch => 'x86_64')

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
  task :yum_diff,[:os,:os_version,:simp_version,:arch] => [:yum_scaffold] do |t,args|
    args.with_defaults(:simp_version => SIMP_VERSION.split('-').first)
    args.with_defaults(:arch => 'x86_64')

    differences_found = false

    target_dir = get_target_dir(args)

    known_packages_hash = get_known_packages(target_dir)

    known_packages = known_packages_hash.keys
    downloaded_packages = get_downloaded_packages(target_dir)

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
        puts "  ~ #{package}"
      end
    end

    if differences_found
      exit 1
    else
      puts("=== No Differences Found ===")
      exit 0
    end
  end
end
