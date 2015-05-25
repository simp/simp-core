#!/usr/bin/rake -T

# This Rakefile merges the SIMP DVD build with the SIMP tarball build, or
# main Rakefile.
#
# Run 'rake -D' for a good summary of options.

require 'ruby-progressbar'
require 'rake/clean'

# Optional Verbosity
be_verbose = ENV.fetch('SIMP_RAKE_VERBOSE','false')
be_verbose =~ /true/i ? verbose(true) : verbose(false)

RUNDIR     = Dir.pwd
BASEDIR    = File.dirname(__FILE__)
BUILD_ARCH = ENV['buld_arch'] || %x{#{:facter} hardwaremodel 2>/dev/null}.chomp
BUILD_DIR  = "#{BASEDIR}/build"
DIST_DIR   = "#{BUILD_DIR}/dist"
DVD_DIR    = "#{BUILD_DIR}/DVD_Overlay"
SRC_DIR    = "#{BASEDIR}/src"
DVD_SRC    = "#{SRC_DIR}/DVD"
SPEC_DIR   = "#{SRC_DIR}/build"
SPEC_FILES = FileList["#{SPEC_DIR}/*.spec"]
TARGET_DISTS = ['RHEL','CentOS']

# NOTE: simp/rake and simp/rpm should be available as a gem.  However, if that
# gem is not present, the git:submodules:reset task in git.rake should be
# enough to pull down a local copy.
begin
  require 'simp/rake'
  include Simp::Rake
  SIMP_VERSION = Simp::RPM.get_info("#{SPEC_DIR}/simp.spec")[:full_version]
rescue LoadError => e
  warn "WARNING: #{e.message}"
end

RHEL_VERSION = ENV['rhel_version'] || '6'

SIMP_DVD_DIRS  = ["SIMP","ks","Config"]

Dir["#{File.dirname(__FILE__)}/rakefiles/*.rake"].each do |ext|
  begin
    puts "== loading '#{ext}' " if be_verbose && false
    load ext
  rescue LoadError => e
    warn "WARNING: #{e.message}"
    next
  end
end

CLEAN.include(
  "#{DIST_DIR}/*",
  ".discinfo",
  DVD_DIR,
  "#{BUILD_DIR}/SIMP"
)

CLOBBER.include(
  DIST_DIR,
  "#{BUILD_DIR}/gpgkeys/dev"
)

# This just abstracts the clean/clobber space in such a way that clobber can actally be used!
def advanced_clean(type,args)
  fail "Type must be one of 'clean' or 'clobber'" unless ['clean','clobber'].include?(type)

  validate_in_mock_group?

  mock_dirs = Dir.glob("/var/lib/mock/*").map{|x| x = File.basename(x) }

  if not mock_dirs.empty? and not args.chroot then
    $stderr.puts "Notice: You must pass a Mock chroot to erase a specified build root."
  end

  Rake::Task["pkg:#{type}"].invoke(args.chroot)
end

task :clobber,[:chroot] do |t,args|
  advanced_clean('clobber',args)
end

task :clean,[:chroot] do |t,args|
  advanced_clean('clean',args)
end

task :default do
  help
end
