require 'highline/import'
require 'yaml'
require 'fileutils'

require File.expand_path( '../../cli', File.dirname(__FILE__) )
require File.expand_path( '../config/item', File.dirname(__FILE__) )
require File.expand_path( '../config/questionnaire', File.dirname(__FILE__) )
require File.expand_path( '../config/item_list_factory', File.dirname(__FILE__) )

module Simp::Cli::Commands; end

# Handle CLI interactions for "simp config"
class Simp::Cli::Commands::Config  < Simp::Cli
  default_outfile = '~/.simp/simp_conf.yaml'

  @version         = Simp::Cli::VERSION
  @advanced_config = false
  @options         = {
    :verbose            => 0,
    :noninteractive     => 0,
    :dry_run            => false, # TODO: between these two, we should choose better names

    :input_file         => nil,
    :output_file        => File.expand_path( default_outfile ),
    :puppet_system_file => '/etc/puppet/environments/production/hieradata/simp_def.yaml',

    :use_safety_save        => true,
    :autoaccept_safety_save => false,
  }

  @opt_parser      = OptionParser.new do |opts|
    opts_separator = ' '*4 + '-'*76
    opts.banner = "\n=== The SIMP Configuration Tool === "
    opts.separator ""
    opts.separator "The SIMP Configuration Tool is designed to assist the configuration of a SIMP"
    opts.separator "machine. It offers two main features:"
    opts.separator ""
    opts.separator "   (1) create/edit system configurations, and"
    opts.separator "   (2) apply system configurations."
    opts.separator ""
    opts.separator "The features that will be used is dependent upon the options specified."
    opts.separator ""
    opts.separator "USAGE:"
    opts.separator "  #{File.basename($0)} config [KEY=VALUE] [KEY=VALUE1,,VALUE2,,VALUE3] [...]"
    opts.separator ""
    opts.separator "OPTIONS:\n"
    opts.separator opts_separator

    opts.on("-o", "--output FILE", "The answers FILE where the created/edited ",
                                   "system configuration will be written.  ",
                                   "  (defaults to '#{default_outfile}')") do |file|
      @options[:output_file] = file
    end

    opts.on("-i", "-a", "-e", "--apply FILE", "Apply a pre-existing answers FILE. ",
                                              "  Note that the edited configuration",
                                              "  will be written to the file specified in ",
                                              "   --output.") do |file|
      @options[:input_file] = file
    end

    opts.separator opts_separator

    # TODO: improve nomenclature
    opts.on("-v", "--verbose", "Verbose output (stacks)") do
      @options[:verbose] += 1
    end

    opts.on("-q", "--quiet", "Quiet output (clears any verbosity)") do
      @options[:verbose] = -1
    end

    opts.on("-n", "--dry-run",         "Do not apply system changes",
                                       "  (e.g., NICs, puppet.conf, etc)" ) do
      @options[:dry_run] = true
    end

    opts.on("-f", "--non-interactive", "Force default answers (prompt if unknown)",
                                       "  (-ff fails instead of prompting)") do |file|
      @options[:noninteractive] += 1
    end

    opts.on("-s", "--skip-safety-save",         "Ignore any saftey-save files") do
      @options[:use_safety_save] = false
    end

    opts.on("-S", "--accept-safety-save",  "Automatically apply any saftey-save files") do
      @options[:autoaccept_safety_save] = true
    end

    opts.separator opts_separator

    opts.on("-h", "--help", "Print this message") do
      puts opts
      exit 0
    end
  end


  def self.saved_session
    result = {}
    if @options.fetch( :use_safety_save, false ) && file = @options.fetch( :output_file )
      _file = File.join( File.dirname( file ), ".#{File.basename( file )}" )
      if File.file?( _file )
        lines      = File.open( _file, 'r' ).readlines
        saved_hash = read_answers_file _file
        last_item  = nil
        if saved_hash.keys.size > 0
          last_item = {saved_hash.keys.last =>
                       saved_hash[ saved_hash.keys.last ]}.to_yaml.gsub( /^---/, '' ).strip
        end

        message = %Q{WARNING: interrupted session detected!}
        say "<%= color(%q{*** #{message} ***}, YELLOW, BOLD) %> \n\n"
        say "<%= color(%q{An automatic safety-save file from a previous session has been found at:}, YELLOW) %> \n\n"
        say "      <%= color( %q{#{_file}}, BOLD ) %>\n\n"
        if last_item
          say "<%= color(%q{The most recent answer from this session was:}, YELLOW) %> \n\n"
          say "<%= color( %q{#{last_item.gsub( /^/, "      \0" )}} ) %>\n\n"
        end

        if @options.fetch( :autoaccept_safety_save, false )
          color = 'YELLOW'
          say "<%= color(%q{Automatically resuming these answers because }, #{color}) %>" +
              "<%= color(%q{--accept-safety-save}, BOLD, #{color}) %>" +
              "<%= color(%q{ is active.}, #{color}) %>\n\n"
          result = saved_hash
        else
          say "<%= color(%q{You can resume these answers or delete the file.}, YELLOW) %>\n\n"

          if agree( "resume the session? (no = deletes file)" ){ |q| q.default = 'yes' }
            say "\n<%= color( %q{applying answers from '#{_file}'}, GREEN )%>\n"
            result = saved_hash
          else
            say "\n<%= color( %q{removing file '#{_file}'}, RED )%>\n"
            FileUtils.rm_f _file, :verbose => true
          end
        end
        sleep 1
      end
    end
    result
  end


  def self.remove_saved_session
    if file = @options.fetch( :output_file )
      _file = File.join( File.dirname( file ), ".#{File.basename( file )}" )
      FileUtils.rm_f( _file, :verbose => false ) if File.file?( _file )
    end
  end


  def self.read_answers_file file
    answers_hash = {}    # Read the input file

    if file
      unless File.exist?(file)
        raise "Could not access the file '#{file}'!"
      end
    else
      file = @options[:system_file]
    end

    begin
      answers_hash = YAML.load(File.read(file))
      answers_hash.empty?
    rescue Errno::EACCES
      error = "WARNING: Could not access the anwers file '#{file}'!"
      say "<%= color(%q{#{error}}, YELLOW) %>\n"
    rescue
      # If the file existed, but ingest failed, then there's a problem
      raise "System Configuration File: '#{file}' is corrupted.\nReview the file and either fix or remove it before trying again."
    end

    answers_hash
  end



  def self.run(args = [])
    begin
      super # parse @options
    rescue OptionParser::InvalidOption=> e
      error = "ERROR: #{e.message}"
      say "\n<%= color(%q{#{error}}, RED) %>\n"
      puts @opt_parser
      exit 1
    end

    # read in answers file
    answers_hash = {}
    if file = @options.fetch( :input_file )
      answers_hash = read_answers_file( file )
    end

    # NOTE: answers from an interrupted session take precedence over input file
    answers_hash = saved_session.merge( answers_hash )

    # NOTE: answers provided from the cli take precendence over everything else
    cli_answers  = Hash[ ARGV[1..-1].map{ |x| x.split '=' } ]
    answers_hash = answers_hash.merge( cli_answers )

    # get the list of items
    #  - applies any known answers at this point
    item_list          = Simp::Cli::Config::ItemListFactory.new( @options ).process( nil, answers_hash )

    # process items:
    #  - get any remaining answers
    #  - apply changes as needed
    questionnaire      = Simp::Cli::Config::Questionnaire.new( @options )
    answers            = questionnaire.process( item_list, {} )

    remove_saved_session
  end
end
