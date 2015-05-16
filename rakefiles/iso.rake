#!/usr/bin/rake -T
require 'simp/rake'
include Simp::Rake

File.umask(0007)

namespace :iso do

  # Remove packages from the given directory. The goal of this method is to help
  # get the distro to be as small as possible.
  # [:from_dir] Root directory to remove packages from (removes recursively)
  # [:exclude_dirs] Array of directories to not remove any packages from
  # [:exclude_pkgs] Array of packages to not remove
  def prune_packages(from_dir,exclude_dirs,exclude_pkgs,mkrepo='createrepo -p',use_hack=true)
    $stderr.puts "Starting to prune..."
    Dir.chdir(from_dir) do
      prune_count = 0

      Find.find('.') do |path|
        Find.prune if exclude_dirs.include?(File.basename(path))

        if File.basename(path) =~ /.*\.rpm/ then
          # Get the package name from the RPM.
          # Note: an alternative method may be to just simply check the names
          # of the RPMs themselves instead of the names of the packages.
          pkg = nil
          if use_hack then
            # The proper way (defined below) is way too slow, so this hack helps
            # speed up the process by reading the file directly. If the code is
            # not working, attempt this without using the hack, just be ready
            # to wait a long time for the code to complete.
            pkgname = File.basename(path).split('-').first
            File.open(path,'r').each_line do |line|
              if encode_line(line) =~ /C\000(\S+\000)?(#{Regexp.escape(pkgname)}\S*)\000/ then
                pkg = $2.split(/\000/).first
                break
              end
            end
          else
            # Proper way to obtain the RPM's package name, but WAY too slow
            pkg = %x{rpm -qp --qf "%{NAME}" #{path} 2>/dev/null}.chomp
          end

          if not exclude_pkgs.include?(pkg) then
            rm(path)
            prune_count += 1
          end
        end
      end
      $stderr.puts "Info: Pruned #{prune_count} packages from #{from_dir}"

      if prune_count > 0 then
        # Recreate the now-pruned repos
        basepath = '.'
        if (File.basename(from_dir) =~ /^RHEL/) then
          # This covers old versions of RHEL that don't follow the new
          # way of doing things.
          if not Dir.glob("Server/*.rpm").empty? then
            basepath = 'Server'
          end
        end

        Dir.chdir(basepath) do
          cp(Dir.glob("repodata/*comps*.xml").first,"simp_comps.xml")
          sh %{#{mkrepo} -g simp_comps.xml .}
          rm("simp_comps.xml")
        end
      end
    end
  end # End of prune_packages

  desc "Build the SIMP ISO(s).
 * :tarball - Path of the source tarball or directory containing the source
     tarballs.
 * :unpacked_dvds - Path of the directory containing the unpacked base OS
     directories. Default is the current directory.
 * :prune - Flag for whether unwanted packages should be pruned prior to
     building the ISO. Default is true."
  task :build,[:tarball,:unpacked_dvds,:prune] do |t,args|
    args.with_defaults(:unpacked_dvds => "#{RUNDIR}", :prune => 'true')

    if args.tarball.nil? then
      fail "Error: You must specify a source tarball or tarball directory!"
    else
      tarball = File.expand_path(args.tarball)
      if not File.exist?(tarball) then
        fail "Error: Could not find tarball at '#{tarball}'!"
      end
    end

    tarfiles = File.directory?(tarball) ?
      Dir.glob("#{tarball}/*.tar.gz") : [tarball]
    vermap = YAML::load_file("#{BASEDIR}/rakefiles/vermap.yaml")

    tarfiles.each do |tarball|
      namepieces = File.basename(tarball,".tar.gz").split('-')
      simpver = namepieces[3..-1].join('-')
      baseos = namepieces[2]

      iso_dirs = Dir.glob("#{File.expand_path(args.unpacked_dvds)}/#{baseos}*")
      if iso_dirs.empty? then
        fail "Error: No unpacked DVD directories found for '#{baseos}'"
      end

      # Process each unpacked base OS ISO directory found
      iso_dirs.each do |dir|
        baseosver = '???'
        arch      = '???'

        # read the .treeinfo file (INI format)
        # ------------------------------------
        require 'puppet'
        require 'puppet/util/inifile'

        file = "#{dir}/.treeinfo"
        File.file? file or error( "ERROR: no file '#{file}'")

        ini = Puppet::Util::IniConfig::PhysicalFile.new( file )
        ini.read
        sections = ini.sections.map{ |s| s.name }

        # NOTE: RHEL7 discs claim [general] section is deprecated.
        if sections.include? 'general'
          h = Hash[ ini.get_section( 'general' ).entries ]
          arch      = h.fetch( 'arch',    arch ).strip
          baseosver = h.fetch( 'version', baseosver ).strip
          baseosver += '.0' if baseosver.count('.') < 1
        end
        # ------------------------------------

        # Skip if SIMP version doesn't match target base OS version
        next if not vermap[simpver.split('.').first].eql?(baseosver.split('.').first)

        mkrepo = baseosver.split('.').first == '5' ? 'createrepo -s sha -p' : 'createrepo -p'

        SIMP_DVD_DIRS.each do |clean_dir|
          if File.directory?("#{dir}/#{clean_dir}") then
            rm_rf("#{dir}/#{clean_dir}")
          elsif File.file?("#{dir}/#{clean_dir}") then
            fail "Error: #{dir}/#{clean_dir} is a file, expecting directory!"
          end
        end

        # Prune unwanted packages
        begin
          system("tar --no-same-permissions -C #{dir} -xzf #{tarball} *simp_pkglist.txt")
        rescue
          # Does not matter if the command fails
        end
        if args.prune.casecmp("false") != 0 and File.exist?("#{dir}/#{baseosver.split('.').first}-simp_pkglist.txt") then
          exclude_pkgs = Array.new
          File.read("#{dir}/#{baseosver.split('.').first}-simp_pkglist.txt").each_line do |line|
            next if line =~ /^(\s+|#.*)$/
            exclude_pkgs.push(line.chomp)
          end
          prune_packages(dir,['SIMP'],exclude_pkgs,mkrepo)
        end

        # Add the SIMP code
        system("tar --no-same-permissions -C #{dir} -xzf #{tarball}")
        Dir.chdir("#{dir}/SIMP") do
          Dir.glob('*').each do |arch_dir|
            next if not File.directory?(arch_dir) or arch_dir.eql?('noarch')

            Dir.chdir(arch_dir) do
              Find.find('../noarch') do |find_rpm|
                if File.extname(find_rpm).eql?('.rpm') then
                  ln_s(find_rpm,File.basename(find_rpm))
                end
              end
              system("#{mkrepo} .") or fail "Error: Could not run createrepo in #{Dir.pwd}"
            end
          end
        end

        # Make sure we have all of the necessary RPMs!
        Rake::Task['pkg:repoclosure'].invoke(File.expand_path(dir))

        # Do some sane chmod'ing and build ISO
        system("chmod -fR u+rwX,g+rX,o=g #{dir}")
        system("mkisofs -uid 0 -gid 0 -o SIMP-#{simpver}-#{baseos}-#{baseosver}-#{arch}.iso -b isolinux/isolinux.bin -c boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -r -m TRANS.TBL #{dir}")
      end
    end # End of tarfiles loop
  end

  desc <<-EOM
  Build the source ISO.
    Note: The process clobbers the temporary and built files, rebuilds the
    tarball(s) and then packages the source ISO. Therefore it will take a
    while.
      * :key - The GPG key to sign the RPMs with. Defaults to 'prod'.
      * :chroot - An optional Mock Chroot. If this is passed, the tar:build task will be called.
  EOM
  task :src,[:key,:chroot] do |t,args|
    args.with_defaults(:key => 'prod')

    if Dir.glob("#{DVD_DIR}/*.gz").empty? and not args.chroot then
      fail "Error: Could not find compiled source tarballs, please pass a chroot."
    end

    Rake::Task['tar:build'].invoke(args.chroot) if args.chroot

    Dir.chdir(BASEDIR) do
      File.basename(Dir.glob("#{DVD_DIR}/*.tar.gz").first,'.tar.gz') =~ /SIMP-DVD-[^-]+-(.+)/
      name = "SIMP-#{$1}"
      sh %{mkisofs -uid 0 -gid 0 -D -A #{name} -J -joliet-long -m ".git*" -m "./build/tmp" -m "./build/SRPMS" -m "./build/RPMS" -m "./build/signkeys" -o #{name}.src.iso .}
    end
  end
end
