#!/usr/bin/rake -T

require 'yaml'

class FakeLibrarian
  attr_accessor :mods, :forge
  def initialize( puppetfile )
    @puppetfile = puppetfile
    _init_vars
  end

  def modules
    _init_vars
    txt = File.open( @puppetfile ).readlines
    eval(txt.join)
    @mods
  end

  def puppetfile
    str = StringIO.new
    str.puts "forge '#{@forge}'\n\n" if @forge
    @mods.each do |name,opts|
      str.puts "mod '#{name}',"
      str.puts (opts.map{|k,v| "  :#{k} => '#{v}'"}).join(",\n") , ''
    end
    str.string
  end

  private

  def _init_vars
    @mods = {}
    @forge = nil
  end

  def mod( name, args )
    puts name
    @mods[name] = args
  end

  def forge( forge )
    @forge = forge
  end
end


namespace :deps do
  desc <<-EOM
  Checks out all dependency repos.

  This task runs 'librarian-puppet' and updates all dependencies.

  Arguments:
    * :method  => The update method to use (Default => 'tracking'
         tracking => checks out each dep (by branch) according to Puppetfile.tracking
         refs     => checks out each dep (by ref) according to in Puppetfile.refs
  EOM
  task :checkout, [:method] do |t,args|
    args.with_defaults(:method => 'tracking')
    FileUtils.ln_s( "Puppetfile.#{args[:method]}", 'Puppetfile', :force => true )
    Bundler.with_clean_env do
      sh 'bundle exec librarian-puppet-pr328 install --use-forge=false --verbose'
    end
    FileUtils.remove_entry_secure "Puppetfile"
  end

  desc 'Records the current dependencies into Puppetfile.refs.'
  task :record do
    pwd        = Dir.pwd
    top_dir     = File.expand_path('..', File.dirname(__FILE__))
    puppetfile  = File.expand_path('Puppetfile.tracking', top_dir)
    config_file = File.expand_path('.librarian/puppet/config',top_dir)
    configs     = YAML.load_file(config_file)
    lp_path     = configs.fetch( 'LIBRARIAN_PUPPET_PATH' )
    fake_lp     = FakeLibrarian.new( puppetfile )
    modules     = fake_lp.modules
    modules.each do |name,mod|
      Dir.chdir top_dir # paths will be relative
      _name = name.split('-').last
      path = mod.fetch( :path, File.join(lp_path,_name) )
      Dir.chdir path
      modules[name][:ref] = %x{git rev-parse --verify HEAD}.strip
    end
    fake_lp.mods = modules
    Dir.chdir top_dir
    File.open('Puppetfile.refs','w'){|f| f.puts fake_lp.puppetfile }
    Dir.chdir pwd
  end
end

