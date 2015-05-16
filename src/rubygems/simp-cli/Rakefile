$: << File.expand_path( '../lib/', __FILE__ )

require 'rubygems'
require 'rake/clean'
require 'simp/cli'
require 'fileutils'
require 'find'

@package='simp-cli'
@rakefile_dir=File.dirname(__FILE__)


CLEAN.include "#{@package}-*.gem"
CLEAN.include 'pkg'
CLEAN.include 'dist'
Find.find( @rakefile_dir ) do |path|
  if File.directory? path
    CLEAN.include path if File.basename(path) == 'tmp'
  else
    Find.prune
  end
end


desc 'Ensure gemspec-safe permissions on all files'
task :chmod do
  gemspec = File.expand_path( "#{@package}.gemspec", @rakefile_dir ).strip
  spec = Gem::Specification::load( gemspec )
  spec.files.each do |file|
    FileUtils.chmod 'go=r', file
  end
end

desc 'special notes about these rake commands'
task :help do
  puts %Q{
== environment variables ==
SIMP_RPM_BUILD     when set, alters the gem produced by pkg:gem to be RPM-safe.
                   'pkg:gem' sets this automatically.
  }
end

desc 'run all RSpec tests'
task :spec do
  Dir.chdir @rakefile_dir
  sh 'bundle exec rspec spec'
end

desc %q{run all RSpec tests (alias of 'spec')}
task :test => :spec

namespace :pkg do
  @specfile_template = "rubygem-#{@package}.spec.template"
  @specfile          = "build/rubygem-#{@package}.spec"

  # ----------------------------------------
  # DO NOT UNCOMMENT THIS: the spec file requires a lot of tweaking
  # ----------------------------------------
  #  desc "generate RPM spec file for #{@package}"
  #  task :spec => [:clean, :gem] do
  #    Dir.glob("pkg/#{@package}*.gem") do |pkg|
  #      sh %Q{gem2rpm -t "#{@specfile_template}" "#{pkg}" > "#{@specfile}"}
  #    end
  #  end

  desc "build rubygem package for #{@package}"
  task :gem => :chmod do
    Dir.chdir @rakefile_dir
    Dir['*.gemspec'].each do |spec_file|
      cmd = %Q{SIMP_RPM_BUILD=1 bundle exec gem build "#{spec_file}"}
      sh cmd
      FileUtils.mkdir_p 'dist'
      FileUtils.mv Dir.glob("#{@package}*.gem"), 'dist/'
    end
  end


  desc "build and install rubygem package for #{@package}"
  task :install_gem => [:clean, :gem] do
    Dir.chdir @rakefile_dir
    Dir.glob("dist/#{@package}*.gem") do |pkg|
      sh %Q{bundle exec gem install #{pkg}}
    end
  end


  desc "generate RPM for #{@package}"
    require 'tmpdir'
    task :rpm, [:mock_root] => [:clean, :gem] do |t, args|
      mock_root  = args[:mock_root]
      # TODO : Get rid of this terrible code.  Shoe-horned in until
      # we have a better idea for auto-decet
      if mock_root =~ /^epel-6/ then el_version = '6'
      elsif mock_root =~ /^epel-7/ then el_version = '7'
      else puts 'WARNING: Did not detect epel version'
      end
      tmp_dir = ''

      if tmp_dir = ENV.fetch( 'SIMP_MOCK_SIMPGEM_ASSETS_DIR', false )
         FileUtils.mkdir_p tmp_dir
      else
         tmp_dir = Dir.mktmpdir( "build_#{@package}" )
      end

      begin
        Dir.chdir tmp_dir
        specfile     = "#{@rakefile_dir}/build/rubygem-#{@package}.el#{el_version}.spec"
        tmp_specfile = "#{tmp_dir}/rubygem-#{@package}.el#{el_version}.spec"

        # We have to copy to a local directory because mock bugs out in NFS
        # home directories (where SIMP devs often work)
        FileUtils.cp specfile, tmp_specfile, :preserve => true
        Dir.glob("#{@rakefile_dir}/dist/#{@package}*.gem") do |pkg|
          FileUtils.cp pkg, tmp_dir, :preserve => true
        end

        # Build SRPM from specfile
        sh %Q{mock -r #{mock_root} --buildsrpm --source="#{tmp_dir}" --spec="#{tmp_specfile}" --resultdir="#{tmp_dir}"}

        # Build RPM from SRPM
        Dir.glob("#{tmp_dir}/rubygem-#{@package}-*.el#{el_version}*.src.rpm") do |pkg|
          sh %Q{mock -r #{mock_root} --rebuild "#{pkg}" --resultdir=#{tmp_dir} --no-cleanup-after}
        end

        sh %Q{ls -l "#{tmp_dir}"}

        # copy RPM back into pkg/
        Dir.glob("#{tmp_dir}/rubygem-#{@package}-*.el#{el_version}*.rpm") do |pkg|
          sh %Q{cp "#{pkg}" "#{@rakefile_dir}/dist/"}
          FileUtils.cp pkg, "#{@rakefile_dir}/dist/"
        end
      ensure
        Dir.chdir @rakefile_dir
        # cleanup if needed
        if ! ENV.fetch( 'SIMP_MOCK_SIMPGEM_ASSETS_DIR', false )
           FileUtils.remove_entry_secure tmp_dir
        end
      end
  end
end

# vim: syntax=ruby
