#!/usr/bin/env ruby
class Simp
  current_dir = File.dirname(File.expand_path(__FILE__)) + '/simp'

  require 'optparse'
  require current_dir + '/lib/utils'

  protected
  def self.menu
    puts "Usage: simp [command]"
    puts
    puts "  Commands"
    @commands.each do |command_name, command_class|
      puts "    - " + command_name
    end
      puts "    - help [command]"
    puts
  end

  def self.help
    puts @opt_parser.to_s
    puts
  end

  def self.run(args = [])
    @opt_parser.parse!
  end

  private
  def self.version
    begin
      %x{rpm -q simp}.split(/\n/).last.match(/([0-9]+\.[0-9]+\.?[0-9]*)/)[1]
    rescue
      #raise "Simp is not installed!"
      '4.1'
    end
  end

  # load the commands from commands/*.rb and grab the classes that are simp commands
  Dir.glob(current_dir + '/commands/*.rb').sort_by(&:to_s).each do |command_file|
    require command_file
  end

  @commands = Simp::Commands::constants.inject({}) do |commands, constant|
    obj = Simp::Commands.const_get(constant)
    if obj.respond_to?(:superclass) and obj.superclass == Simp
      commands[constant.to_s.downcase] = obj
    end
    commands
  end
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
