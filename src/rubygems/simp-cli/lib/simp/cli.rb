$LOAD_PATH << File.expand_path( '..', File.dirname(__FILE__) )

# namespace for SIMP logic
module Simp; end

# namespace for SIMP CLI commands
class Simp::Cli
  VERSION = '1.0.0'

  require 'optparse'
  require 'simp/cli/lib/utils'

  def self.menu
    puts 'Usage: simp [command]'
    puts
    puts '  Commands'
    @commands.keys.each do |command_name|
      puts "    - #{command_name}"
    end
    puts '    - help [command]'
    puts
  end

  def self.help  # <-- lol.
    puts @opt_parser.to_s
    puts
  end

  def self.run(*)
    @opt_parser.parse!
  end

  private
  def self.version
    cmd = 'rpm -q simp'
    begin
      `#{cmd}`.split(/\n/).last.match(/([0-9]+\.[0-9]+\.?[0-9]*)/)[1]
    rescue
      msg = "Cannot find SIMP OS installation via `#{cmd}`!"
      say '<%= color( "WARNING: ", BOLD, YELLOW ) %>' +
          "<%= color( '#{msg}', YELLOW) %>"
    end
  end

  def self.start
    # load each command
    commands_path = File.expand_path( 'cli/commands/*.rb', File.dirname(__FILE__) )

    # load the commands from commands/*.rb and grab the classes that are simp commands
    Dir.glob( commands_path ).sort_by(&:to_s).each do |command_file|
      require command_file
    end

    @commands = {}
    Simp::Cli::Commands::constants.each{ |constant|
      obj = Simp::Cli::Commands.const_get(constant)
      if obj.respond_to?(:superclass) and obj.superclass == Simp::Cli
        @commands[constant.to_s.downcase] = obj
      end
    }
    @commands['version'] = self

    if ARGV.length == 0 or (ARGV.length == 1 and ARGV[0] == 'help')
      menu
    elsif ARGV[0] == 'version'
      puts version
    elsif ARGV[0] == 'help'
      if (command = @commands[ARGV[1]]).nil?
        puts "\n\033[31m#{ARGV[1]} is not a recognized command\033[39m\n\n"
        menu
      elsif ARGV[1] == 'version'
        puts "Display the current version of SIMP."
      else
        command.help
      end
    elsif (command = @commands[ARGV[0]]).nil?
      puts "\n\033[31m#{ARGV[0]} is not a recognized command\033[39m\n\n"
      menu
    else
      begin
        command.run(ARGV.drop(1))
      rescue => e
        puts "\n\033[31m#{e.message}\033[39m\n\n"
        e.backtrace.first(10).each{|l| puts l }
      end
    end
  end
end
