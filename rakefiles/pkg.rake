#!/usr/bin/rake -T

require 'simp/rake'
include Simp::Rake

MOCK = ENV['mock'] || '/usr/bin/mock'

task :help do
  puts <<-EOF.gsub(/^  /, '')
    SIMP_RAKE_CHOWN_EVERYTHING=(Y|N)
        If 'Y', builds are preceded by a massive chown -R mock on the entire source tree

    EOF
end

namespace :pkg do
  @mock = MOCK

  ##############################################################################
  # Main tasks
  ##############################################################################

  # Have to get things set up inside the proper namespace
  task :prep do
    @build_dirs = {
      :modules => get_module_dirs,
      :aux => [
        "#{BUILD_DIR}/GPGKEYS",
        "#{SRC_DIR}/puppet/bootstrap",
        "#{SRC_DIR}/rsync",
        "#{SRC_DIR}/utils"
      ],
      :doc => "#{SRC_DIR}/doc",
      :simp_cli => "#{SRC_DIR}/rubygems/simp-cli",
      :simp => "#{SRC_DIR}",
    }

    @pkg_dirs = {
      :simp => "#{BUILD_DIR}/SIMP",
      :ext  => "#{BUILD_DIR}/Ext_*"
    }
  end

  task :mock_prep do
    chown_everything = ENV.fetch( 'SIMP_RAKE_CHOWN_EVERYTHING', 'Y' ).chomp.index( %r{^(1|Y|true|yes)$}i ) || false

    verbose(true) do
      next if not chown_everything
      # Set the permissions properly for mock to dig through your source
      # directories.
      chown_R(nil,'mock',BASEDIR)
      # Ruby >= 1.9.3 chmod_R('g+rXs',BASEDIR)
      Find.find(BASEDIR) do |path|
        if File.directory?(path)
          %x{chmod g+rXs #{Shellwords.escape(path)}}
        end
      end
    end
  end

  task :clean,[:chroot] => [:prep] do |t,args|
    validate_in_mock_group?
    @build_dirs.each_pair do |k,dirs|
      Parallel.map(
        Array(dirs),
        :in_processes => get_cpu_limit,
        :progress => t.name
      ) do |dir|
        Dir.chdir(dir) do
          begin
            sh %{rake clean[#{args.chroot}]}
          rescue Exception => e
            raise Parallel::Kill
          end

        end
      end
    end

    # FIXME: not thread-safe
    %x{mock -r #{args.chroot} --scrub=all} if args.chroot
  end

  task :clobber,[:chroot] => [:prep] do |t,args|
    validate_in_mock_group?
    @build_dirs.each_pair do |k,dirs|
      Parallel.map(
        Array(dirs),
        :in_processes => get_cpu_limit,
        :progress => t.name
      ) do |dir|
        Dir.chdir(dir) do
          sh %{rake clobber[#{args.chroot}]}
        end
      end
    end
  end

  desc <<-EOM
    Prepare the GPG key space for a SIMP build.

    If passed anything but 'dev', will fail if the directory is not present in
    the 'build/build_keys' directory.
  EOM
  task :key_prep,[:key] do |t,args|
    require 'securerandom'

    args.with_defaults(:key => 'dev')

    Dir.chdir("#{BUILD_DIR}/build_keys") {
      if (args.key != 'dev')
        fail("Could not find GPG keydir '#{args.key}' in '#{Dir.pwd}'") unless File.directory?(args.key)
      end

      mkdir('dev') unless File.directory?('dev')
      chmod(0750,'dev')

      Dir.chdir('dev') {
        Dir.glob('*').each do |todel|
          rm(todel)
        end

        expire_date = (DateTime.now + 14)
        now = Time.now.to_i.to_s
        dev_email = 'simp@development.key'
        passphrase = SecureRandom.base64(500)

        gpg_infile = <<-EOM
%echo Generating Development GPG Key
%echo
%echo This key will expire on #{expire_date}
%echo
Key-Type: DSA
Key-Length: 2048
Subkey-Type: ELG-E
Subkey-Length: 2048
Name-Real: SIMP Development
Name-Comment: Development key #{now}
Name-Email: #{dev_email}
Expire-Date: 2w
Passphrase: #{passphrase}
%pubring pubring.gpg
%secring secring.gpg
# The following creates the key, so we can print "Done!" afterwards
%commit
%echo New GPG Development Key Created
        EOM

        File.open('gengpgkey','w'){ |fh| fh.puts(gpg_infile) }

        sh %{gpg --homedir=#{Dir.pwd} --batch --gen-key gengpgkey}
        sh %{gpg --homedir=#{Dir.pwd} --armor --export #{dev_email} > RPM-GPG-KEY-SIMP-Dev}
      }

      Dir.chdir(args.key) {
        rpm_build_keys = Dir.glob('RPM-GPG-KEY-*')
        target_dir = '../../GPGKEYS'

        fail("Could not find any RPM-GPG-KEY files in '#{Dir.pwd}'") if rpm_build_keys.empty?
        fail("No GPGKEYS directory at '#{Dir.pwd}/#{target_dir}") unless File.directory?(target_dir)

        dkfh = File.open("#{target_dir}/.dropped_keys",'w')

        rpm_build_keys.each do |gpgkey|
          cp(gpgkey,target_dir)
          dkfh.puts(gpgkey)
        end

        dkfh.flush
        dkfh.close
      }
    }
  end

  desc <<-EOM
    Build the entire SIMP release
      Building this environment requires a working Mock setup (http://fedoraproject.org/wiki/Projects/Mock)
      * :chroot - The Mock chroot configuration to use. See the '--root' option in mock(1).
      * :docs - Build the docs. Set this to false if you wish to skip building the docs.
      * :key - The GPG key to sign the RPMs with. Defaults to 'dev'.
  EOM
  task :build,[:chroot,:docs,:key,:snapshot_release] => [:prep,:mock_prep,:key_prep] do |t,args|
    validate_in_mock_group?

    args.with_defaults(:key => 'dev')
    args.with_defaults(:docs => true)

    output_dir = @pkg_dirs[:simp]

    check_dvd_env

    Rake::Task['pkg:modules'].invoke(args.chroot)
    Rake::Task['pkg:aux'].invoke(args.chroot)
    if "#{args.docs}" == 'true'
      Rake::Task['pkg:doc'].invoke(args.chroot)
    end
    Rake::Task['pkg:simp_cli'].invoke(args.chroot)

    # The main SIMP RPM must be built last!
    Rake::Task['pkg:simp'].invoke(args.chroot,args.snapshot_release)

    # Prepare for the build!
    rm_rf(output_dir)

    # Copy all the resulting files into the target output directory
    mkdir_p(output_dir)

    @build_dirs.each_pair do |k,dirs|
      Array(dirs).each do |dir|
        rpms = Dir.glob("#{dir}/dist/*.rpm")
        srpms = []
        rpms.delete_if{|x|
          del = false
          if x =~ /\.src\.rpm$/
            del = true
            srpms << x
          end

          del
        }

        srpms.each do |srpm|
          out_dir = "#{output_dir}/SRPMS"
          mkdir_p(out_dir) unless File.directory?(out_dir)

          if not uptodate?("#{out_dir}/#{File.basename(srpm)}",[srpm])
            cp(srpm,out_dir)
          end
        end

        rpms.each do |rpm|
          out_dir = "#{output_dir}/RPMS/#{rpm.split('.')[-2]}"
          mkdir_p(out_dir) unless File.directory?(out_dir)

          if not uptodate?("#{out_dir}/#{File.basename(rpm)}",[rpm])
            cp(rpm,out_dir)
          end
        end
      end
    end

    Rake::Task['pkg:signrpms'].invoke(args.key)
  end

  desc <<-EOM
    Build the Puppet module RPMs
      This also builds the simp-mit RPM due to its location.
      Building this environment requires a working Mock setup (http://fedoraproject.org/wiki/Projects/Mock)
      * :chroot - The Mock chroot configuration to use. See the '--root' option in mock(1).
  EOM
  task :modules,[:chroot] => [:prep,:mock_prep] do |t,args|
    build(args.chroot,@build_dirs[:modules],t)
  end

  desc <<-EOM
    Build simp config rubygem RPM
  EOM
  task :simp_cli,[:chroot] => [:prep,:mock_prep] do |t,args|
    build(args.chroot,@build_dirs[:simp_cli],t)
  end

  desc <<-EOM
    Build the SIMP non-module RPMs
      Building this environment requires a working Mock setup (http://fedoraproject.org/wiki/Projects/Mock)
      * :chroot - The Mock chroot configuration to use. See the '--root' option in mock(1).
  EOM
  task :aux,[:chroot] => [:prep,:mock_prep]  do |t,args|
    build(args.chroot,@build_dirs[:aux],t)
  end

  desc <<-EOM
    Build the SIMP documentation
      Building this environment requires a working Mock setup (http://fedoraproject.org/wiki/Projects/Mock)
      * :chroot - The Mock chroot configuration to use. See the '--root' option in mock(1).
  EOM
  task :doc,[:chroot] => [:prep,:mock_prep] do |t,args|
    build(args.chroot,@build_dirs[:doc],t)
  end

  desc <<-EOM
    Build the main SIMP RPM
      Building this environment requires a working Mock setup (http://fedoraproject.org/wiki/Projects/Mock)
      * :chroot - The Mock chroot configuration to use. See the '--root' option in mock(1).
      * :snapshot_release - Will add a define to the Mock to set snapshot_release to current date and time.
  EOM
  task :simp,[:chroot,:snapshot_release] => [:prep,:mock_prep] do |t,args|
    build(args.chroot,@build_dirs[:simp],t,false,args.snapshot_release)
  end

  desc "Sign the RPMs."
  task :signrpms,[:key,:rpm_dir] => [:prep,:mock_prep] do |t,args|
    args.with_defaults(:key => 'dev')
    args.with_defaults(:rpm_dir => "#{BUILD_DIR}/SIMP/*RPMS")

    rpm_dirs = Dir.glob(args.rpm_dir)
    to_sign = []

    rpm_dirs.each do |rpm_dir|
      Find.find(rpm_dir) do |rpm|
        next unless File.readable?(rpm)
        to_sign << rpm if rpm =~ /\.rpm$/
      end
    end

    Parallel.map(
      to_sign,
      :in_processes => get_cpu_limit,
      :progress => t.name
    ) do |rpm|
      rpminfo = %x{rpm -qip #{rpm} 2>/dev/null}.split("\n")
      if not rpminfo.grep(/Signature\s+:\s+\(none\)/).empty?
        Simp::RPM.signrpm(rpm,"#{BUILD_DIR}/build_keys/#{args.key}")
      end
    end
  end

  desc <<-EOM
    Check that RPMs are signed.
      Checks all RPM files in a directory to see if they are trusted.
        * :rpm_dir - A directory containing RPM files to check. Default #{BUILD_DIR}/SIMP
        * :key_dir - The path to the GPG keys you want to check the packages against. Default #{BUILD_DIR}/GPGKEYS
  EOM
  task :checksig,[:rpm_dir,:key_dir] => [:prep] do |t,args|
    begin
      args.with_defaults(:rpm_dir => @pkg_dirs[:ext])
      args.with_defaults(:key_dir => "#{BUILD_DIR}/GPGKEYS")

      rpm_dirs = Dir.glob(args.rpm_dir)

      fail("Could not find files at #{args.rpm_dir}!") if rpm_dirs.empty?

      temp_gpg_dir = Dir.mktmpdir

      rpm_cmd = %{rpm --dbpath #{temp_gpg_dir}}

      sh %{#{rpm_cmd} --initdb}

      # Only import thngs that look like GPG keys...
      Dir.glob("#{args.key_dir}/*").each do |key|
        next if File.directory?(key) or not File.readable?(key)

        File.read(key).each_line do |line|
          if line =~ /-----BEGIN PGP PUBLIC KEY BLOCK-----/
            sh %{#{rpm_cmd} --import #{key}}
            break
          end
        end
      end

      bad_rpms = []
      rpm_dirs.each do |rpm_dir|
        Find.find(rpm_dir) do |path|
          if (path =~ /.*\.rpm$/)
            result = %x{#{rpm_cmd} --checksig #{path}}.strip
            if result !~ /:.*\(\S+\).* OK$/
              bad_rpms << path.split(/\s/).first
            end
          end
        end
      end

      if !bad_rpms.empty?
        bad_rpms.map!{|x| x = "  * #{x}"}
        bad_rpms.unshift("ERROR: Untrusted RPMs found in the repository:")

        fail(bad_rpms.join("\n"))
      else
        puts "Checksig succeeded"
      end
    ensure
      remove_entry_secure temp_gpg_dir
    end
  end

  desc <<-EOM
    Run repoclosure on rpm files
      Finds all rpm files in the target dir and all of its subdirectories, then
      reports which packages have unresolved dependencies. This needs to be run
      after rake tasks tar:build and unpack if operating on the base SIMP repo.
        * :target_dir  - The directory to assess. Default #{BUILD_DIR}/SIMP.
        * :aux_dir     - Auxillary repo glob to use when assessing. Default #{BUILD_DIR}/Ext_*.
                        Defaults to ''(empty) if :target_dir is not the system default.

  EOM
  task :repoclosure,[:target_dir,:aux_dir] => [:prep] do |t,args|
    default_target = @pkg_dirs[:simp]
    args.with_defaults(:target_dir => default_target)
    if args.target_dir == default_target
      args.with_defaults(:aux_dir => @pkg_dirs[:ext])
    else
      args.with_defaults(:aux_dir => '')
    end

    yum_conf_template = <<-EOF
[main]
keepcache=0
exactarch=1
obsoletes=1
gpgcheck=0
plugins=1
installonly_limit=5

<% repo_files.each do |repo| -%>
include=file://<%= repo %>
<% end -%>
    EOF

    yum_repo_template = <<-EOF
[<%= repo_name %>]
name=<%= repo_name %>
baseurl=file://<%= repo_path %>
enabled=1
gpgcheck=0
protect=1
    EOF

    fail "#{args.target_dir} does not exist!" if not File.directory?(args.target_dir)

    begin
      temp_pkg_dir = Dir.mktmpdir

      mkdir_p("#{temp_pkg_dir}/repos/base")
      mkdir_p("#{temp_pkg_dir}/repos/lookaside")
      mkdir_p("#{temp_pkg_dir}/repodata")

      Dir.glob(args.target_dir).each do |base_dir|
        Find.find(base_dir) do |path|
          if (path =~ /.*\.rpm$/) and (path !~ /.*.src\.rpm$/)
            sym_path = "#{temp_pkg_dir}/repos/base/#{File.basename(path)}"
            ln_s(path,sym_path) unless File.exists?(sym_path)
          end
        end
      end

      Dir.glob(args.aux_dir).each do |aux_dir|
        Find.find(aux_dir) do |path|
          if (path =~ /.*\.rpm$/) and (path !~ /.*.src\.rpm$/)
            sym_path = "#{temp_pkg_dir}/repos/lookaside/#{File.basename(path)}"
            ln_s(path,sym_path) unless File.exists?(sym_path)
          end
        end
      end

      Dir.chdir(temp_pkg_dir) {
        repo_files = []
        Dir.glob('repos/*').each do |repo|
          if File.directory?(repo)
            Dir.chdir(repo) {
              sh %{createrepo .}
            }

            repo_name = File.basename(repo)
            repo_path = File.expand_path(repo)
            conf_file = "#{temp_pkg_dir}/#{repo_name}.conf"

            File.open(conf_file,'w') { |file|
              file.write(ERB.new(yum_repo_template,nil,'-').result(binding))
            }

            repo_files << conf_file
          end
        end

        File.open('yum.conf', 'w') { |file|
          file.write(ERB.new(yum_conf_template,nil,'-').result(binding))
        }

        sh %{repoclosure -c repodata -n -t -r base -l lookaside -c yum.conf}
      }
    ensure
      remove_entry_secure temp_pkg_dir
    end
  end

  ##############################################################################
  # Helper methods
  ##############################################################################

  # Takes a list of directories to hop into and perform builds within
  # Needs to be passed the chroot path as well
  #
  # The task must be passed so that we can output the calling name in the
  # status bar.
  def build(chroot,dirs,task,add_to_autoreq=true,snapshot_release=false)
    validate_in_mock_group?

    mock_pre_check(chroot)

    # Default package metadata for reference
    default_metadata = YAML.load(File.read("#{SRC_DIR}/build/package_metadata_defaults.yaml"))

    metadata = Parallel.map(
      Array(dirs),
      :in_processes => get_cpu_limit,
      :progress => task.name
    ) do |dir|
      result = []

      Dir.chdir(dir) do
        if File.exist?('Rakefile')
          # Read the package metadata file and proceed accordingly.
          module_metadata = default_metadata
          if File.exist?('build/package_metadata.yaml')
            module_metadata.merge!(YAML.load(File.read('build/package_metadata.yaml')))
          end

          # SIMP_VERSION should be set in the main Rakefile
          build_module = false
          Array(module_metadata['valid_versions']).each do |version_regex|
            build_module = Regexp.new("^#{version_regex}$").match(SIMP_VERSION)
            break if build_module
          end

          if build_module
            unique_build = (get_cpu_limit != 1)
            sh %{rake pkg:rpm[#{chroot},unique_build,#{snapshot_release}]}

            # Glob all generated rpms, and add their metadata to a result array.
            pkginfo = Hash.new
            Dir.glob('dist/*.rpm') do |rpm|
              if not rpm =~ /.*.src.rpm/ then
                # get_info from each generated rpm, not the spec file, so macros in the
                # metadata have already been resolved in the mock chroot.
                pkginfo = Simp::RPM.get_info(rpm)
                result << [pkginfo,module_metadata]
              end
            end
          else
            puts "Warning: #{Simp::RPM.get_info(Dir.glob('build/*.spec').first)[:name]} is not \
valid against SIMP version #{SIMP_VERSION.gsub("%{?snapshot_release}","")} and will not be built."
          end
        else
          puts "Warning: Could not find Rakefile in '#{dir}'"
        end
      end

      result
    end

    metadata.each do |i|
      # Each module could generate multiple rpms, each with its own metadata.
      # Iterate over them to add all built rpms to autorequires.
      i.each do |module_pkginfo,module_metadata|
        next unless (module_pkginfo and module_metadata)

        # Set up the autorequires
        if add_to_autoreq and not module_metadata['optional']
          # Register the package with the autorequires
          mode = 'r+'
          mode = 'w+' unless File.exist?("#{SRC_DIR}/build/autorequires")
          autoreq_fh = File.open("#{SRC_DIR}/build/autorequires",mode)

          begin
            autorequires = []
            autorequires += autoreq_fh.read.split("\n")
            autoreq_fh.rewind
            autoreq_fh.truncate(0)

            # The SIMP Rakefile expects the autorequires to be in this format.
            autorequires << "#{module_pkginfo[:name]} #{module_pkginfo[:version]} #{module_pkginfo[:release]}"
            autoreq_fh.puts(autorequires.sort.uniq.join("\n"))
          ensure
            autoreq_fh.flush
            autoreq_fh.close
          end
        end
      end
    end
  end

  #desc "Checks the environment for building the DVD tarball
  def check_dvd_env
    ["#{DVD_SRC}/isolinux","#{DVD_SRC}/ks"].each do |dir|
      File.directory?(dir)or raise "Environment not suitable: Unable to find directory '#{dir}'"
    end
  end

  # Return a list of all puppet module directories with Rakefiles
  def get_module_dirs
    moddir = "#{SRC_DIR}/puppet/modules"

    toret = []

    Dir.glob("#{moddir}/*").map { |x| x = File.basename(x).chomp }.sort.each do |mod|
      if File.exist?("#{moddir}/#{mod}/Rakefile")
          toret << "#{moddir}/#{mod}"
      end
    end

    toret
  end

  # Get a list of all of the mock configs available on the system.
  def get_mock_configs
    Dir.glob('/etc/mock/*.cfg').sort.map{ |x| x = File.basename(x,'.cfg')}
  end

  # Run some pre-checks to make sure that mock will work properly.
  # Pass init=false if you do not want the function to initialize.
  #
  # Returns 'true' if the space is already initialized.
  # FIXME: unique_name doesn't work
  # FIXME: unique_name is never called
  def mock_pre_check(chroot,unique_name=false,init=true)
    raise(Exception,"Could not find mock on your system, exiting") unless File.executable?('/usr/bin/mock')

    mock_configs = get_mock_configs

    if not chroot
      fail("Error: No mock chroot provided. Your choices are:\n#{mock_configs.join("\n  ")}"
      )
    end
    if not mock_configs.include?(chroot)
      fail("Error: Invalid mock chroot provided. Your choices are:\n#{mock_configs.join("\n  ")}"
      )
    end

    # Allow for building all modules in parallel.
    @mock = "#{@mock} --uniqueext=#{PKGNAME}" if unique_name

    # A simple test to see if the chroot is initialized
    %x{#{@mock} -q --root #{chroot} --chroot "test -d /tmp" --quiet &> /dev/null}
    initialized = $?.success?

    if init and not initialized
      cmd = %{#{@mock} --root #{chroot} --init}
      sh cmd
    end

    initialized
  end
end
