#!/usr/bin/rake -T

require 'simp/rake/pupmod/helpers'

Simp::Rake::Beaker.new(File.dirname(__FILE__))

begin
  require 'simp/rake/build/helpers'
  BASEDIR    = File.dirname(__FILE__)
  Simp::Rake::Build::Helpers.new( BASEDIR )
rescue LoadError => e
  warn "WARNING: #{e.message}"
end

task :metadata_lint do
  sh 'metadata-json-lint --strict-dependencies --strict-license --fail-on-warnings metadata.json'
end

task :default do
  help
end

namespace :deps do
  desc <<-EOM
  Remove all checked-out dependency repos

  Uses specified Puppetfile to identify the checked-out repos.

  Arguments:
    * :suffix       => The Puppetfile suffix to use (Default => 'tracking')
    * :remove_cache => Whether to remove the R10K cache after removing the
                       checked-out repos (Default => false)
  EOM
  task :clean, [:suffix,:remove_cache] do |t,args|
    args.with_defaults(:suffix => 'tracking')
    args.with_defaults(:remove_cache => false)
    base_dir = File.dirname(__FILE__)

    r10k_helper = R10KHelper.new("Puppetfile.#{args[:suffix]}")

    r10k_issues = Parallel.map(
      Array(r10k_helper.modules),
        :in_processes => get_cpu_limit,
        :progress => 'Dependency Removal'
    ) do |mod|
      Dir.chdir(base_dir) do
        FileUtils.rm_rf(mod[:path])
      end
    end

    if args[:remove_cache]
      cache_dir = File.join(base_dir, '.r10k_cache')
      FileUtils.rm_rf(cache_dir)
    end
  end
end

namespace :pkg do
  desc <<-EOM
  Remove all built artifacts in build/

  Arguments:
    * :remove_yum_cache   => Whether to remove the yum cache (Default => true)
    * :remove_dev_gpgkeys => Whether to remove the SIMP Dev GPG keys (Default => true)
  EOM
  task :build_clean, [:remove_yum_cache,:remove_dev_gpgkeys] do |t,args|
    args.with_defaults(:remove_yum_cache => 'true')
    args.with_defaults(:remove_dev_gpgkeys => 'true')

    base_dir = File.dirname(__FILE__)
    #                                                          OS   ver  arch
    distr_glob = File.join(base_dir, 'build', 'distributions', '*', '*', '*')

    dirs_to_remove = [
      Dir.glob(File.join(distr_glob, 'SIMP*')),
      Dir.glob(File.join(distr_glob, 'DVD_Overlay'))
    ]

    if args[:remove_yum_cache] == 'true'
      dirs_to_remove += Dir.glob(File.join(distr_glob, 'yum_data', 'packages'))
    end

    if args[:remove_dev_gpgkeys] == 'true'
      dirs_to_remove += Dir.glob(File.join(distr_glob, 'build_keys', 'dev'))
      dirs_to_remove += Dir.glob(File.join(distr_glob, 'DVD', 'RPM-GPG-KEY-SIMP-Dev'))
    end
    dirs_to_remove.flatten.each { |dir| FileUtils.rm_rf(dir, :verbose =>true) }
  end
end
