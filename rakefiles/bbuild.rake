#!/usr/bin/rake -T

require 'simp/rake'
include Simp::Rake

class SIMPBuildException < Exception
end

require 'pry'
require 'simp/build/release_mapper'
namespace :build do
  desc <<-EOM
  Automatically detect and build a SIMP ISO for a target SIMP release.

  This task runs all other build tasks

  Arguments:
    * :release     => SIMP release to build (e.g., '5.1.X')
    - :iso_paths   => path to source ISO(s) (colon-delimited list of files/directories) [Default: '.']
    - :output_dir  => path to write SIMP ISO.   [Default: './SIMP_ISO']
    - :tarball     => SIMP build tarball file; if given, skips tar build.  [Default: false]
    - :do_checksum => Use sha256sum checksum to compare each ISO.  [Default: false]
    - :key_name    => Key name to sign packages [Default: 'dev']
    - :verbose     => Enable verbose reporting. [Default: false]

  ENV vars:
    - SIMP_ISO_STAGING_DIR   => Path to stage big build assets [Default: './SIMP_ISO_STAGING']
    - SIMP_BUILD_force_dirty => If 'yes', check out sub repos, even if they are dirty
  EOM

  task :auto,  [:release,
                :iso_paths,
                :output_dir,
                :tarball,
                :do_checksum,
                :key_name,
                :verbose] do |t, args|
    # set up data
    # --------------------------------------------------------------------------

    args.with_defaults(
      :iso_paths   => Dir.pwd,
      :output_dir  => '',
      :tarball     => false,
      :do_checksum => false,
      :key_name    => 'dev',
      :verbose     => false,
    )

    # locals
    target_release = args[:release]
    iso_paths      = File.expand_path(args[:iso_paths])
    output_dir     = args[:output_dir].sub(/^$/, File.expand_path( 'SIMP_ISO', Dir.pwd ))
    tarball        = args[:tarball]
    do_checksum    = args[:do_checksum]
    key_name       = args[:key_name]
    staging_dir    = ENV.fetch('SIMP_ISO_STAGING_DIR',
                                File.expand_path( 'SIMP_ISO_STAGING', Dir.pwd ))
    verbose        = (args.verbose == 'false' ? false : true)

    yaml_file      = File.expand_path('../build/release_mappings.yaml',
                                        File.dirname(__FILE__))
    pwd            = Dir.pwd
    repo_root_dir  = File.expand_path( '..', File.dirname(__FILE__) )
    method         = 'tracking'
    do_docs        = false
    @dirty_repos   = nil

    # Look up ISOs against known build assets
    # --------------------
    target_data = get_target_data(target_release, iso_paths, yaml_file, do_checksum, verbose )

    # IDEA: check for prequisite build tools

    # check out subrepos
    # --------------------
    puts '='*80
    puts "== Checking out subrepositories"
    puts '='*80
    Dir.chdir repo_root_dir
    Rake::Task['deps:status'].invoke
    if @dirty_repos && !ENV['SIMP_BUILD_force_dirty'] == 'yes'
      raise SIMPBuildException, "ERROR: Dirty repos detected!  I refuse to destroy uncommitted work."
    else
      puts '-'*80
      puts "==== Checking out subrepositories using method '#{method}'"
      puts '-'*80
      Rake::Task['deps:checkout'].invoke(method)
    end


    # build tarball
    # --------------------
    # TODO: detect tarball file if it exists
    if !tarball
      puts
      puts
      puts '='*80
      puts "==== Running bundler in all repos"
      puts '='*80
      Rake::Task['build:bundle'].invoke

      puts
      puts '='*80
      puts "==== Running tar:build in all repos"
      puts '='*80
      Rake::Task['tar:build'].invoke(target_data['mock'],key_name,do_docs)
    else
      puts
      puts '='*80
      puts "==== Using tarball '#{tarball}'"
      puts '='*80
    end

    # yum
    puts
    puts '='*80
    puts "==== rake build:yum:sync[#{target_data['flavor']},#{target_data['os_version']}]"
    puts '='*80
    Rake::Task['build:yum:sync'].invoke(target_data['flavor'],target_data['os_version'])

    # If you have previously downloaded packages from yum, you may need to run 
    # $ rake build:yum:clean_cache

    # Optionally, you may drop in custom packages you wish to have available during an install into build/yum_data/SIMP<simp_version>_<CentOS or RHEL><os_version>_<architecture>/packages
    # TODO: ENV var for optional packages

    # ready staging environment
    # --------------------
    FileUtils.mkdir_p staging_dir, :verbose => verbose
    Dir.chdir staging_dir

    # yum
    puts
    puts '='*80
    puts "==== unpack ISOs into staging directory"
    puts "     staging area: '#{staging_dir}'"
    puts '='*80
    target_data['isos'].each do |iso|
      puts "---- rake unpack[#{iso}]"
      #Rake::Task['unpack'].invoke(iso,false,Dir.pwd,'isoinfo',target_data['os_version'])
      #Rake::Task['unpack'].invoke(iso)
      Dir.glob( File.join(staging_dir, "#{target_data['flavor']}*/") ).each do |f|
        FileUtils.rm_f( f  , :verbose => verbose )
      end
      Rake::Task['unpack'].invoke(iso,true,staging_dir)
    end

    require 'find'
    #FileUtils.mkdir_p target_release, :verbose => verbose
    #Dir.chdir         target_release
    # cp -rl ../orig/CentOS6.7-x86_64 .
    # yum
    puts
    puts '='*80
    puts "==== iso:build[#{tarball}]"
    puts '='*80

    Rake::Task['iso:build'].invoke(tarball)

    
    isos = []
    binding.pry
  end

end

def get_target_data(target_release, iso_paths, yaml_file, do_checksum, verbose )
  puts '='*80
  puts "== validating ISOs for target:"
  puts "      '#{target_release}' in '#{iso_paths}'"
  puts '='*80
  puts

  mapper          = Simp::Build::ReleaseMapper.new(target_release, yaml_file, do_checksum)
  mapper.verbose  = true || verbose
  target_data     = mapper.autoscan_unpack_list( iso_paths )

  puts '-'*80
  puts "== validation results:"
  puts '-'*80
  puts '--'
  puts "--   target release: '#{target_release}'"
  puts "--   target flavor:  '#{target_data['flavor']}'"
  puts "--   source isos:"
  target_data['isos'].each do |iso|
    puts "--      - #{iso}"
  end
  puts

  target_data
end

