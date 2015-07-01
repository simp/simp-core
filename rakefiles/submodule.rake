#!/usr/bin/rake -T
namespace :submodule do

  include Simp::Rake
  include FileUtils

  desc "Run bundle in every submodule (in gitmodules)"
  task :bundle do
    # http://stackoverflow.com/questions/13262608/bundle-package-fails-when-run-inside-rake-task
    system %Q(/usr/bin/env RUBYOPT= bundle package)

    # Grab all currently tracked submodules.
    $modules = (Simp::Git.submodules_in_gitmodules.keys).sort.uniq.unshift('')

    basedir = pwd()
    $modules.each do |mod|
      moddir = basedir +  "/#{mod}"
      next if not File.directory? moddir
      puts moddir
      FileUtils.cd(moddir)
      # Any ruby code that opens a subshell will automatically use the current Bundler environment.
      # Clean env will give bundler the environment present before Bundler is activated.
      Bundler.with_clean_env do
        puts `bundle`
      end
    end
  end
end
