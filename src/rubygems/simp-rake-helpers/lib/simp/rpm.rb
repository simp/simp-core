module Simp
  # Simp::RPM represents a single package that is built and packaged by the Simp team.
  class Simp::RPM
    require 'expect'
    require 'pty'

    @@gpg_keys = Hash.new
    attr_accessor :basename, :version, :release, :full_version, :name, :sources, :verbose

    if Gem.loaded_specs['rake'].version >= Gem::Version.new('0.9') then
      def self.sh(args)
        system args
      end
    end

    # Constructs a new Simp::RPM object. Requires the path to the spec file that
    # will be used to create the package.
    #
    # The following information will be retreived from the spec file:
    # [basename] The name of the package (as it would be queried in yum)
    #            (extracted from the basename of the spec file)
    # [version] The version of the package
    # [release] The release version of the package
    # [full_version] The full version of the package: [version]-[release]
    # [name] The full name of the package: [basename]-[full_version]
    def initialize(specfile)
      info = Simp::RPM.get_info(specfile)
      @basename = info[:name]
      @version = info[:version]
      @release = info[:release]
      @full_version = info[:full_version]
      @name = "#{@basename}-#{@full_version}"
      @sources = Array.new
    end

    # Copies specific content from one directory to another.
    # start_dir:: the root directory where the original files are located within
    # src:: a pattern given to find(1) to match against the desired files to copy
    # dest:: the destination directory to receive the copies
    def self.copy_wo_vcs(start_dir, src, dest, dereference=true)
      if dereference.nil? || dereference then
        dereference = "--dereference"
      else
        dereference = ""
      end

      Dir.chdir(start_dir) do
        sh %{find #{src} \\( -path "*/.svn" -a -type d -o -path "*/.git*" \\) -prune -o -print | cpio -u --warning none --quiet --make-directories #{dereference} -p "#{dest}" 2>&1 > /dev/null}
      end
    end

    # Parses information, such as the version, from the given specfile into a
    # hash.
    def self.get_info(specfile)
      info = Hash.new
      if File.readable?(specfile) then
        File.open(specfile).each do |line|
          if line =~ /^\s*Version:\s+(.*)\s*/ then
            info[:version] = $1
            next
          elsif line =~ /^\s*Release:\s+(.*)\s*/ then
            info[:release] = $1
            next
          elsif line =~ /^\s*Name:\s+(.*)\s*/ then
            info[:name] = $1
            next
          end
        end
      else
        raise "Error: unable to read the spec file '#{specfile}'"
      end

      info[:full_version] = "#{info[:version]}-#{info[:release]}"

      return info
    end

    # Loads metadata for a GPG key. The GPG key is to be used to sign RPMs. The
    # value of gpg_key should be the full path of the directory where the key
    # resides. If the metadata cannot be found, then the user will be prompted
    # for it.
    def self.load_key(gpg_key)
      keydir = gpg_key
      File.directory?(keydir) or fail "Error: Could not find '#{keydir}'"

      gpg_key = File.basename(gpg_key)

      if @@gpg_keys[gpg_key] then
          return @@gpg_keys[gpg_key]
      end

      gpg_name = nil
      begin
        File.read("#{keydir}/gengpgkey").each_line do |ln|
          ln = ln.split(/^\s*Name-Email:/)
          ln.length > 1 and gpg_name = ln.last.strip and break
        end
      rescue Errno::ENOENT
      end

      if gpg_name.nil? then
        puts "Warning: Could not find valid e-mail address for use with GPG."
        puts "Please enter e-mail address to use:"
        gpg_name = $stdin.gets.strip
      end

      begin
        password = File.read("#{keydir}/password").chomp
      rescue Errno::ENOENT
        puts "Warning: Could not find a password in '#{keydir}/password'!"
        puts "Please enter your GPG key password:"
        system 'stty -echo'
        password = $stdin.gets.strip
        system 'stty echo'
      end

      @@gpg_keys[gpg_key] = { :dir => keydir, :name => gpg_name, :password => password }
    end

    # Signs the given RPM with the given gpg_key (see Simp::RPM.load_key for
    # details on the value of this parameter).
    def self.signrpm(rpm, gpg_key)
      gpgkey = load_key(gpg_key)
      signcommand = "rpm " +
          "--define '%_signature gpg' " +
          "--define '%_gpg_name #{gpgkey[:name]}' " +
          "--define '%_gpg_path #{gpgkey[:dir]}' " +
          "--resign #{rpm}"
      begin
        PTY.spawn(signcommand) do |read, write, pid|
          begin
            read.expect(/Enter pass phrase: /) do |text|
              write.print("#{gpgkey[:password]}\n")
            end
          rescue Errno::EIO
            # This ALWAYS happens in Ruby 1.8.
          end
          Process.wait(pid)
        end
      rescue Exception => e
        puts "Error occured while attempting to sign #{rpm}, skipping."
        puts e
      end
    end
  end
end
