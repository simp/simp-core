#!/usr/bin/rake -T

require 'simp/rake'
include Simp::Rake

class SIMPBuildException < Exception
end

require 'simp/build/release_mapper'
namespace :build do
  desc <<-EOM
  Automatically detect and build a SIMP ISO for a target SIMP release.

  This task runs all other build tasks

  Arguments:
    * :release     => SIMP release to build (e.g., '5.1.X')
    - :iso_paths   => path to source ISO(s) (colon-delimited list of files/directories) [Default: '.']
    - :output_dir  => path to write SIMP ISO.   [Default: './SIMP_ISO']
    - :tarball     => SIMP build tarball file; if given, skips tar build.  [Default: 'false']
    - :do_checksum => Use sha256sum checksum to compare each ISO.  [Default: 'false']
    - :key_name    => Key name to sign packages [Default: 'dev']
    - :verbose     => Enable verbose reporting. [Default: 'false']

  ENV vars:
    - SIMP_BUILD_staging_dir    => Path to stage big build assets [Default: './SIMP_ISO_STAGING']
    - SIMP_BUILD_rm_staging_dir => 'yes' forcibly removes the staging dir before starting
    - SIMP_BUILD_force_dirty    => 'yes' tries to checks out subrepos even if dirty
    - SIMP_BUILD_docs           => 'yes' builds & includes documentation
    - SIMP_BUILD_bundle         => 'no' skips running bundle in each subrepo
    - SIMP_BUILD_unpack         => 'no' skips the unpack section
    - SIMP_BUILD_unpack_merge   => 'no' prevents auto-merging the unpacked DVD
    - SIMP_BUILD_prune          => 'no' passes :prune=>false to iso:build

  Notes:
    - To skip `tar:build` (including `pkg:build`), use the `tarball` argument
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
      :tarball     => 'false',
      :do_checksum => 'false',
      :key_name    => 'dev',
      :verbose     => 'false',
    )

    # locals
    target_release   = args[:release]
    iso_paths        = File.expand_path(args[:iso_paths])
    output_dir       = args[:output_dir].sub(/^$/, File.expand_path( 'SIMP_ISO', Dir.pwd ))
    tarball          = (args.tarball =~ /^(false|)$/ ? false : args.tarball)
    do_checksum      = (args.do_checksum =~ /^$/ ? 'false' : args.do_checksum)
    key_name         = args[:key_name]
    staging_dir      = ENV.fetch('SIMP_BUILD_staging_dir',
                                  File.expand_path( 'SIMP_ISO_STAGING', Dir.pwd ))
    verbose          = (args.verbose == 'false' ? false : true)

    yaml_file        = File.expand_path('../build/release_mappings.yaml',
                                          File.dirname(__FILE__))
    pwd              = Dir.pwd
    repo_root_dir    = File.expand_path( '..', File.dirname(__FILE__) )
    method           = ENV.fetch('SIMP_BUILD_puppetfile','tracking')
    do_rm_staging    = ENV['SIMP_BUILD_rm_staging_dir'] == 'yes'
    do_docs          = ENV['SIMP_BUILD_docs'] == 'yes' ? 'true' : 'false'
    do_unpack        = ENV['SIMP_BUILD_unpack'] != 'no'
    do_merge         = ENV['SIMP_BUILD_unpack_merge'] != 'no'
    do_prune         = ENV['SIMP_BUILD_prune'] != 'no' ? 'true' : 'false'
    do_bundle        = ENV['SIMP_BUILD_bundle'] != 'no'
    @dirty_repos     = nil
    @simp_output_iso = nil

    if do_rm_staging && !do_unpack
      fail "ERROR: Mixing `SIMP_BUILD_rm_staging_dir=yes` and `SIMP_BUILD_unpack=no` is silly."
    end



    # Look up ISOs against known build assets
    # --------------------
    target_data = get_target_data(target_release, iso_paths, yaml_file, do_checksum, verbose )

    # IDEA: check for prequisite build tools

    # check out subrepos
    # --------------------
    puts
    puts '='*80
    puts "## Checking out subrepositories"
    puts '='*80
    Dir.chdir repo_root_dir
    Rake::Task['deps:status'].invoke
    if @dirty_repos && !ENV['SIMP_BUILD_force_dirty'] == 'yes'
      raise SIMPBuildException, "ERROR: Dirty repos detected!  I refuse to destroy uncommitted work."
    else
      puts
      puts '-'*80
      puts "#### Checking out subrepositories using method '#{method}'"
      puts '-'*80
      Rake::Task['deps:checkout'].invoke(method)
    end

    if do_bundle
      puts
      puts '-'*80
      puts "#### Running bundler in all repos"
      puts '     (Disable with `SIMP_BUILD_bundle=no`)'
      puts '-'*80
      Rake::Task['build:bundle'].invoke
    else
      puts
      puts '-'*80
      puts "#### SKIPPED: bundler in all repos"
      puts '     (Force with `SIMP_BUILD_bundle=yes`)'
      puts '-'*80
    end

    # build tarball
    # --------------------
    if tarball
      puts
      puts '-'*80
      puts "#### Using pre-existing tarball:"
      puts "           '#{tarball}'"
      puts
      puts '-'*80

      ver=target_data['os_version'].split('.').first
      repo_pkglist_file = File.expand_path( "src/DVD/#{ver}-simp_pkglist.txt",
                                            repo_root_dir
                                          )
      if File.file? repo_pkglist_file
        puts "#### setting SIMP_PKGLIST_FILE=#{repo_pkglist_file}"
        ENV['SIMP_PKGLIST_FILE']=repo_pkglist_file
      else
        puts "#### WARNING: repo pkglist file not found:"
        puts "              '#{repo_pkglist_file}'"
        puts
      end
    else
      puts
      puts '='*80
      puts "#### Running tar:build in all repos"
      puts '='*80
      @simp_tarballs = {}
      Rake::Task['tar:build'].invoke(target_data['mock'],key_name,do_docs)
      tarball = @simp_tarballs.fetch(target_data['flavor'])
    end

    # yum sync
    # --------------------
    puts
    puts '-'*80
    puts "#### rake build:yum:sync[#{target_data['flavor']},#{target_data['os_version']}]"
    puts '-'*80
    Rake::Task['build:yum:sync'].invoke(target_data['flavor'],target_data['os_version'])

    # If you have previously downloaded packages from yum, you may need to run
    # $ rake build:yum:clean_cache

    # Optionally, you may drop in custom packages you wish to have available during an install into build/yum_data/SIMP<simp_version>_<CentOS or RHEL><os_version>_<architecture>/packages
    # TODO: ENV var for optional packages

    prepare_staging_dir( staging_dir, do_rm_staging, repo_root_dir, verbose )
    Dir.chdir staging_dir

    #
    # --------------------
    if do_unpack
      puts
      puts '='*80
      puts "#### unpack ISOs into staging directory"
      puts "     staging area: '#{staging_dir}'"
      puts
      puts "     (skip with `SIMP_BUILD_unpack=no`)"
      puts '='*80
      puts
      target_data['isos'].each do |iso|
        puts "---- rake unpack[#{iso}]"
        Dir.glob( File.join(staging_dir, "#{target_data['flavor']}*/") ).each do |f|
          FileUtils.rm_f( f , :verbose => verbose )
        end
        Rake::Task['unpack'].invoke(iso,do_merge,Dir.pwd,'isoinfo',target_data['os_version'])
      end
    else
      puts
      puts '='*80
      puts "#### skipping ISOs unpack (because `SIMP_BUILD_unpack=no`)"
      puts
    end

    puts
    puts '='*80
    puts "#### iso:build[#{tarball}]"
    puts '='*80
    puts

    Rake::Task['iso:build'].invoke(tarball,staging_dir,do_prune)


    puts
    puts '='*80
    puts "#### Moving '#{@simp_output_iso}' into:"
    puts "       '#{output_dir}'"
    puts '='*80
    puts

    # TODO: error out if output_dir exists but is not a directory
    FileUtils.mkdir_p output_dir, :verbose => verbose
    FileUtils.mv(@simp_output_iso,"#{output_dir}/",:verbose => verbose)
  end

end

def get_target_data(target_release, iso_paths, yaml_file, do_checksum, verbose )
  puts '='*80
  puts "## validating ISOs for target:"
  puts "      '#{target_release}' in '#{iso_paths}'"
  puts '='*80
  puts

  mapper          = Simp::Build::ReleaseMapper.new(target_release, yaml_file, do_checksum == 'true')
  mapper.verbose  = true || verbose
  target_data     = mapper.autoscan_unpack_list( iso_paths )

  puts '-'*80
  puts "## target data:"
  puts ''
  puts "     target release: '#{target_release}'"
  puts "     target flavor:  '#{target_data['flavor']}'"
  puts "     source isos:"
  target_data['isos'].each do |iso|
    puts "        - #{iso}"
  end
  puts '-'*80
  puts
  sleep 3.seconds

  target_data
end


def prepare_staging_dir( staging_dir, do_rm_staging, repo_root_dir, verbose )
  if ['','/',Dir.home,repo_root_dir].include? staging_dir
    fail "ERROR: staging directoy path is too stupid to be believed:\n"+
         "       '#{staging_dir}'\n\n" +
         "       use SIMP_BUILD_staging_dir='path/to/staging/dir'\n\n"
  end
  if do_rm_staging
    puts
    puts '-'*80
    puts '#### Ensuring previous staging directory is removed:'
    puts "       '#{staging_dir}'"
    puts
    puts '     (disable this with `SIMP_BUILD_rm_staging_dir=no`)'
    puts '-'*80

    FileUtils.rm_rf staging_dir, :verbose => verbose
  elsif File.exists? staging_dir
    warn ''
    warn '!'*80
    warn '#### WARNING: staging dir already exists at:'
    warn "              '#{staging_dir}'"
    warn ''
    warn '              - Previously staged assets in this directory may cause problems.'
    warn '              - Use `SIMP_BUILD_rm_staging_dir=yes` to remove it automatically.'
    warn ''
    warn '!'*80
    warn ''
    sleep 10.seconds
  end
  FileUtils.mkdir_p staging_dir, :verbose => verbose
end
