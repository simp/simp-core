module Simp; end
module Simp::Rake
  require 'rubygems'
  require 'erb'
  require 'rake/clean'
  require 'find'
  require 'yaml'
  require 'shellwords'
  require 'parallel'
  require 'tempfile'
  require 'simp/rpm'
  require 'simp/rake/pkg'

  # Force the encoding to something that Ruby >= 1.9 is happy with
  def encode_line(line)
    if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('1.9')
      require 'iconv'
      line = Iconv.new('ISO-8859-1//IGNORE','UTF-8').iconv(line)
    else
      line = line.force_encoding(Encoding::ISO_8859_1).encode(Encoding::UTF_8,:replace => nil,:undef => :replace)
    end
  end

  # by default, we use all processors - 1
  def get_cpu_limit
    cpus = Parallel.processor_count
    env_cpus = ENV.fetch( 'SIMP_RAKE_LIMIT_CPUS', '-1' ).strip.to_i

    env_cpus  = 1          if env_cpus == 0
    env_cpus += cpus       if env_cpus < 0
    # sanitize huge numbers
    env_cpus  = (cpus - 1) if env_cpus >= cpus
    env_cpus  = 1          if env_cpus < 0

    env_cpus
  end

  # Snarfed from http://nex-3.com/posts/73-git-style-automatic-paging-in-ruby
  def run_pager
    return if RUBY_PLATFORM =~ /win32/
    return unless STDOUT.tty?

    read, write = IO.pipe

    unless Kernel.fork # Child process
      STDOUT.reopen(write)
      STDERR.reopen(write) if STDERR.tty?
      read.close
      write.close
      return
    end

    # Parent process, become pager
    STDIN.reopen(read)
    read.close
    write.close

    ENV['LESS'] = 'FSRX' # Don't page if the input is short enough

    Kernel.select [STDIN] # Wait until we have input before we start the pager
    pager = ENV['PAGER'] || 'less'
    exec pager rescue exec "/bin/sh", "-c", pager
  end

  # Originally snarfed from
  # http://stackoverflow.com/questions/2108727/which-in-ruby-checking-if-program-exists-in-path-from-ruby
  def which(cmd)
    File.executable?(cmd) and return cmd

    cmd = File.basename(cmd)

    exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
    ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
      exts.each { |ext|
        exe = File.join(path, "#{cmd}#{ext}")
        return exe if File.executable? exe
      }
    end

    warn "Warning: Command #{cmd} not found on the system."
    return nil
  end

  # Return whether or not the user is in the mock group
  def validate_in_mock_group?
    if not %x{groups}.split.include?('mock')
      raise(Exception,"You need to be in the 'mock' group.")
    end
  end

  def help
    run_pager

    puts <<-EOM
= SIMP Build Tasks =

Use 'rake' and choose one of the options below that best suits your
needs. If you are simply trying to build the SIMP tarball, use the
'rake tar:build[:chroot]' option.

NOTE: Any task that requires a :chroot input will require you to be in
the 'mock' group and have the 'mock' package installed.

== Space Requirements ==

A full parallel build will take around 500M for each git submodule built.

If you are space limited, set SIMP_RAKE_LIMIT_CPUS=1 at build time.

== Environment Variables ==

* SIMP_RAKE_CHOWN_EVERYTHING=(Y|n)
  - Chown everything to the 'mock' group prior to building

* SIMP_RAKE_MOCK_OFFLINE=(y|N)
  - Mock runs are limited to the local cache

* SIMP_RAKE_LIMIT_CPUS=#
  - Default: Num system CPUs - 1
  - An Integer that limits builds to # processors
  - If set to '1', will only build in a single mock directory

********************
EOM

    sh %{rake -D}
  end
end
