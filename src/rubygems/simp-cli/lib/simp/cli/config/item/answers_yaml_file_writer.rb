require "resolv"
require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::AnswersYAMLFileWriter < ActionItem
    attr_accessor :file, :backup_old_file

    def initialize
      super
      @key             = 'yaml::file_writer'
      @description     = %Q{Writes Config::Item answers so far to YAML file (apply-only; noop).}
      @file            = '/etc/puppet/environments/production/hieradata/simp_def.yaml'
      @backup_old_file = false
    end


    # prints an answers file to an iostream
    def print_answers_yaml( iostream, answers )
      iostream.puts "#======================================="
      iostream.puts "# simp config answers"
      iostream.puts "#"
      iostream.puts "# generated on #{Time.now.to_s}"
      iostream.puts "#---------------------------------------"
      iostream.puts "# you can use these answers to quickly configure subsequent simp installations
                     # by running the command:
                     #
                     #   simp config -a /PATH/TO/THIS/FILE
                     #
                     # simp config will prompt for any missing items
                     ".gsub(/^\s+/, '').strip
      iostream.puts "#======================================="
      iostream.puts "---"
      answers.each do |k,v|
        if yaml = v.to_yaml_s  # filter out nil results (for ruby 1.8)
          iostream.puts yaml
          iostream.puts
        end
      end
    end


    # write a file
    def write_answers_yaml_file( file, answers )
      say_green "Writing answers to: #{file}" if !@silent
      FileUtils.mkdir_p( File.dirname( file ) )
      File.open( file, 'w' ){ |fh| print_answers_yaml( fh, answers ) }
    end


    def apply
      write_answers_yaml_file( @file, @config_items ) if @config_items.size > 0
    end
  end
end
