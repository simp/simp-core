# simp-core additions to deps-namespaced targets
#
# This is a playground for tasks that may eventually be moved to
# simp-rake-helpers or simp-build-helpers
#
require_relative 'simp_core_deps_helper'

include Simp::SimpCoreDepsHelper

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
    base_dir = File.dirname(File.dirname(__FILE__))

    r10k_helper = R10KHelper.new("Puppetfile.#{args[:suffix]}")

    Parallel.map(
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


  desc <<-EOM
  EXPERIMENTAL: Generate a list of SIMP changes since a previous simp-core tag.

  - Output logged to the console
  - Output includes:
    - simp-core changes noted in its git logs
    - simp.spec %changelog changes
    - Individual SIMP component changes noted both in its git logs and its
      CHANGELOG file or %changelog section of its build/<component>.spec file.
      - The changes are from the version listed in the tag's Puppetfile
        to the version specified in the current Puppetfile
  - Output does **not** include any changes of non-SIMP components

  EXAMPLE USAGE:
    bundle exec rake deps:changes_since[6.5.0-1]

  CAUTION:
    Executes `deps:clean` followed by a `deps:checkout`.
    This means you will lose any local changes made to checked out
    component repositories.

  FAILS:
  - The simp-core tag specified is not available locally.
  - The specified Puppetfile at the simp-core tag is not available.

  Arguments:
    * :prev_tag    => simp-core previous version tag
    * :prev_suffix => The Puppetfile suffix to use from the previous simp-core tag;
                      DEFAULT: 'pinned'
    * :curr_suffix => The Puppetfile suffix to use from this simp-core checkout
                      DEFAULT: 'pinned'
    * :brief       => Only show 1 line git log summaries; DEFAULT: false
    * :debug       => Log status gathering actions; DEFAULT: false
  EOM
  task :changes_since, [:prev_tag,:prev_suffix,:curr_suffix,:brief,:debug] do |t,args|
    args.with_defaults(:prev_suffix => 'pinned')
    args.with_defaults(:curr_suffix => 'pinned')
    args.with_defaults(:brief => 'false')
    args.with_defaults(:debug => 'false')

    # ensure starting with a clean deps checkout
    Rake::Task['deps:clean'].invoke(args[:current_suffix])
    Rake::Task['deps:checkout'].invoke(args[:current_suffix])

    base_dir = File.dirname(File.dirname(__FILE__))
    opts = args.to_hash
    opts[:brief] = (opts[:brief] == 'true') ? true : false
    opts[:debug] = (opts[:debug] == 'true') ? true : false
    changes = gather_changes(base_dir, opts)
    log_changes(changes, args[:prev_tag])
  end
end
