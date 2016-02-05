#!/usr/bin/rake -T

require 'yaml'

class FakeLibrarian
  attr_reader :forge, :environment
  attr_accessor :puppetfile
  attr_writer :modules

  require 'librarian/puppet/util'
  include Librarian::Puppet::Util

  require 'librarian/puppet/environment'
  require 'librarian/puppet/source/git'

  def initialize(puppetfile)
    @environment = Librarian::Puppet::Environment.new
    if puppetfile
      @puppetfile = Pathname.new(puppetfile)

      unless @puppetfile.absolute?
        @puppetfile = File.expand_path(@puppetfile,@environment.project_path)
      end
    end
  end

  def modules
    @modules ||= {}

    if @modules.empty?
      txt = File.readlines(@puppetfile)
      eval(txt.join)
    end

    @modules
  end

  # Return a list of modules that are in the install path but not known to the
  # Puppetfile
  def unknown_modules
    known_modules = []
    all_modules = Dir.glob(File.join(@environment.install_path,'*')).map{|x| x = File.basename(x)}

    relative_path = @environment.install_path.to_s.split(@environment.project_path.to_s).last
    relative_path[0] = '' if relative_path[0].chr == File::SEPARATOR

    unless all_modules.empty?
      modules.each do |name,opts|
        known_modules << module_name(name)
      end
    end

    module_list = (all_modules - known_modules).map do |x|
      if File.exist?(File.join(@environment.install_path,x,'metadata.json'))
        x = File.join(relative_path,x)
      else
        x = nil
      end
    end

    module_list.compact
  end

  def puppetfile
    str = StringIO.new
    str.puts "forge '#{@forge}'\n\n" if @forge
    modules.each do |name,opts|
      str.puts "mod '#{name}',"
      str.puts (opts.map{|k,v| "  :#{k} => '#{v}'"}).join(",\n") , ''
    end
    str.string
  end

  def each_module(&block)
    Dir.chdir(@environment.project_path) do
      modules.each do |name,mod|
        # This works for Puppet Modules
        path = File.expand_path(module_name(name),environment.install_path)
        unless File.directory?(path)
          # This works for everything else
          if mod[:path]
            path = File.expand_path(mod[:path],environment.project_path)
          end
        end
        unless File.directory?(path)
          $stderr.puts("Warning: Could not find path for module '#{name}'...skipping")
          next
        end

        block.call(@environment,name,path)
      end
    end
  end

  private

  def mod(name,args)
    @modules[name] = args
  end

  def forge(forge)
    @forge = forge
  end
end

namespace :deps do
  desc <<-EOM
  Checks out all dependency repos.

  This task runs 'librarian-puppet' and updates all dependencies.

  Arguments:
    * :method  => The update method to use (Default => 'tracking')
         tracking => checks out each dep (by branch) according to Puppetfile.tracking
         stable   => checks out each dep (by ref) according to in Puppetfile.stable
  EOM
  task :checkout, [:method] do |t,args|
    args.with_defaults(:method => 'tracking')
    FileUtils.ln_s( "Puppetfile.#{args[:method]}", 'Puppetfile', :force => true )
    Bundler.with_clean_env do
      sh 'bundle exec librarian-puppet-pr328 install --use-forge=false'
    end
    FileUtils.remove_entry_secure "Puppetfile"
  end

  desc <<-EOM
  Get the status of the project Git repositories

  Arguments:
    * :method  => The update method to use (Default => 'tracking')
         tracking => checks out each dep (by branch) according to Puppetfile.tracking
         stable   => checks out each dep (by ref) according to in Puppetfile.stable
  EOM
  task :status, [:method] do |t,args|
    args.with_defaults(:method => 'tracking')
    @dirty_repos = nil

    fake_lp = FakeLibrarian.new("Puppetfile.#{args[:method]}")
    mods_with_changes = {}

    fake_lp.each_module do |environment, name, path|
      unless File.directory?(path)
        $stderr.puts("Warning: '#{path}' is not a module...skipping")
        next
      end

      repo = Librarian::Puppet::Source::Git::Repository.new(environment,path)
      if repo.dirty?
        # Clean up the path a bit for printing
        dirty_path = path.split(environment.project_path.to_s).last
        if dirty_path[0].chr == File::SEPARATOR
          dirty_path[0] = ''
        end

        mods_with_changes[name] = dirty_path
      end
    end

    if mods_with_changes.empty?
      puts "No repositories have changes."
      @dirty_repos = false
    else
      puts "The following repositories have changes:"
      puts mods_with_changes.map{|k,v| "  + #{k} => #{v}"}.join("\n")

      @dirty_repos = true
    end

    unknown_mods = fake_lp.unknown_modules
    unless unknown_mods.empty?
      puts "The following modules were unknown:"
      puts unknown_mods.map{|k,v| "  ? #{k}"}.join("\n")
    end
  end

  desc 'Records the current dependencies into Puppetfile.stable.'
  task :record do
    fake_lp     = FakeLibrarian.new('Puppetfile.tracking')
    modules     = fake_lp.modules

    fake_lp.each_module do |environment, name, path|
      Dir.chdir(path) do
        modules[name][:ref] = %x{git rev-parse --verify HEAD}.strip
      end
    end

    fake_lp.modules = modules
    File.open('Puppetfile.stable','w'){|f| f.puts fake_lp.puppetfile }
  end
end
