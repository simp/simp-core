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


task :default do
  help
end


def modinfo(filename)
  basename = File.basename filename
  s = basename.split(/-/)
  {
    :author  => s[0],
    :name    => s[1],
    :version => s[2].chomp('.tar.gz')
  }
end

namespace :mco_plugins do
  task :build do
    Dir.chdir('src/mcollective/plugins') do
      cmd = ['mco','plugin','package','--format aiomodulepackage','--vendor choria','--config ./build.cfg']

      Dir.glob('**') do |plugin|
        name = plugin
        next unless File.directory? plugin
        run = cmd.dup + [plugin]
        puts "==== packaging plugin #{plugin}"
        `#{run.join(' ')}`
      end
    end
  end

  task :manage do
    metadata = {}
    Dir.glob('src/mcollective/plugins/choria-mcollective*.tar.gz') do |mod|
      metadata = modinfo(mod)

      puts "==== installing #{metadata[:name]} to src/puppet/modules"
      `puppet module install --modulepath src/puppet/modules #{mod}`

      Dir.chdir("src/puppet/modules/#{metadata[:name]}") do
        # require 'pry';binding.pry
        FileUtils.rm_rf('dist') if File.directory? 'dist'
        require 'git'
        g = Git.open(Dir.pwd)
        g.config('user.name','SIMP Team')
        g.config('user.email','simp@simp-project.org')
        g.add(:all=>true)
        begin
          g.commit("MAINT: Update to upstream version #{metadata[:version]}")
        rescue Git::GitExecuteError => e
          puts '==== No git commit needed, it\'s up to date!'
        end

        available_tags = g.tags.map { |t| t.name }
        if !available_tags.include? metadata[:version]
          g.add_tag(metadata[:version], :message => "Repackage of upstream release #{File.basename mod}" )
        end
        puts '==== pushing master and new tags'
        g.push('origin','master', true)
      end
    end


  end

  # task :jank do
  #   Dir.chdir('src/mcollective/plugins') do
  #     cmd  = ['mco','plugin','package']
  #     cmd += ['--format aiomodulepackage','--vendor choria','--config ./build.cfg']
  #
  #     Dir.glob('**') do |plugin|
  #       next unless File.directory? plugin
  #       run = cmd.dup + [plugin]
  #       puts "==== packaging plugin #{plugin}"
  #       `#{run.join(' ')}`
  #     end
  #   end
  #
  #   Dir.glob('src/mcollective/plugins/choria-mcollective*.tar.gz') do |plugin|
  #     puts "==== installing #{plugin} to src/puppet/modules"
  #     `puppet module install --modulepath src/puppet/modules #{plugin}`
  #   end
  #
  #   require 'pry';binding.pry
  #
  # end
  #
  # task :git_init do
  #   Dir.glob('src/puppet/modules/mcollective_*') do |mod|
  #     puts mod
  #     next if mod =~ /mcollective_choria/
  #     Dir.chdir(mod) do
  #       puts Dir.pwd
  #       `git init`
  #       `git add * .*`
  #       `git rm -rf dist/`
  #       `git commit -am"Initial commit"`
  #       `hub create -p -d "A Puppet module package for the MCollective plugin"`
  #       `git push origin master -f`
  #     end
  #   end
  # end
end