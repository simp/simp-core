# frozen_string_literal: true

# Whole-stack checks: test the SIMP module set as a whole, as simp-core
# assembles it, rather than any one module. Each module's own CI keeps it
# usable on its own; these tasks catch drift between modules.
#
#   rake stack:install[pinned]   # r10k-install Puppetfile.pinned into tmp/stack/pinned/modules
#   rake stack:skeleton          # clone simp-environment-skeleton into tmp/stack/
#   rake stack:deps[pinned]      # dependency consistency across the module set
#   rake stack:catalogs[pinned]  # compile skeleton catalogs for each scenario and EL release
#   rake stack:all[pinned]       # all of the above
#
# The Puppetfile argument is `pinned` (default) or `branches`.
#
# Environment variables:
#   STACK_MODULEDIR        install into (or use an existing) module directory
#   STACK_SKELETON         use an existing simp-environment-skeleton checkout
#   STACK_SKELETON_REPO    clone from this URL
#                          (default https://github.com/simp/simp-environment-skeleton.git)
#   STACK_SKELETON_REF     clone this branch or tag (default master)

namespace :stack do
  stack_dir = File.join(__dir__, '..', 'tmp', 'stack')

  set_env = ->(args) do
    args.with_defaults(puppetfile: 'pinned')
    unless ['pinned', 'branches'].include?(args[:puppetfile])
      raise ArgumentError, "Unknown Puppetfile '#{args[:puppetfile]}': use pinned or branches"
    end

    ENV['STACK_PUPPETFILE'] = args[:puppetfile]
    ENV['STACK_MODULEDIR'] ||= File.expand_path(File.join(stack_dir, args[:puppetfile], 'modules'))
  end

  desc 'Install the Puppet modules from Puppetfile.<puppetfile> (pinned or branches) with r10k'
  task :install, [:puppetfile] do |_t, args|
    set_env.call(args)
    source = File.expand_path(File.join(__dir__, '..', "Puppetfile.#{args[:puppetfile]}"))
    moduledir = ENV.fetch('STACK_MODULEDIR')
    FileUtils.mkdir_p(moduledir)

    # The Puppetfiles switch `moduledir` between sections (src, src/assets,
    # src/puppet/modules). Keep only the Puppet module section and point it
    # at the stack directory, so r10k never writes into src/.
    sections = File.read(source).split(%r{^(?=moduledir\s)})
    modules = sections.find { |s| s.match?(%r{\Amoduledir\s+['"]src/puppet/modules['"]}) }
    raise "No `moduledir 'src/puppet/modules'` section in #{source}" unless modules

    puppetfile = File.join(File.dirname(moduledir), 'Puppetfile')
    File.write(puppetfile, modules.sub(%r{\Amoduledir\s+\S+}, "moduledir '#{moduledir}'"))
    sh 'r10k', 'puppetfile', 'install', '--puppetfile', puppetfile, '--moduledir', moduledir, '--force'
  end

  desc 'Clone simp-environment-skeleton (STACK_SKELETON_REF, default master)'
  task :skeleton do
    next if ENV['STACK_SKELETON']

    dir = File.expand_path(File.join(stack_dir, 'simp-environment-skeleton'))
    repo = ENV.fetch('STACK_SKELETON_REPO', 'https://github.com/simp/simp-environment-skeleton.git')
    ref = ENV.fetch('STACK_SKELETON_REF', 'master')
    FileUtils.rm_rf(dir)
    sh 'git', 'clone', '--quiet', '--depth', '1', '--branch', ref, repo, dir
    ENV['STACK_SKELETON'] = dir
  end

  desc 'Check dependencies across the module set (run stack:install first)'
  task :deps, [:puppetfile] do |_t, args|
    set_env.call(args)
    sh 'rspec', '--no-fail-fast', '--format', 'documentation', 'spec/stack/dependencies_spec.rb'
  end

  desc 'Compile skeleton catalogs for each scenario and EL release (run stack:install and stack:skeleton first)'
  task :catalogs, [:puppetfile] do |_t, args|
    set_env.call(args)
    ENV['STACK_SKELETON'] ||= File.expand_path(File.join(stack_dir, 'simp-environment-skeleton'))
    sh 'rspec', '--no-fail-fast', '--format', 'documentation', 'spec/stack/catalogs_spec.rb'
  end

  desc 'Install the module set and run every stack check'
  task :all, [:puppetfile] do |_t, args|
    Rake::Task['stack:install'].invoke(args[:puppetfile])
    Rake::Task['stack:skeleton'].invoke
    failed = []
    ['stack:deps', 'stack:catalogs'].each do |t|
      Rake::Task[t].invoke(args[:puppetfile])
    rescue RuntimeError => e
      warn e.message
      failed << t
    end
    raise "Failed: #{failed.join(', ')}" unless failed.empty?
  end
end
