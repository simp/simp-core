require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )
module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::PuppetAutosign < ListItem
    def initialize
      super
      @key         = 'puppet::autosign'
      @description = %Q{You should place any hostnames/domains here that you wish to autosign.\nThe most security conscious method is to list each individual hostname:\n  hosta.your.domain\n  hostb.your.domain\n\nWildcard domains work, but absolutely should NOT be used unless you fully trust your network.}
      @file        = '/etc/puppet/autosign.conf'
    end

    def os_value
      # TODO: make this a custom fact?
      values = Array.new
      File.readable?(@file) &&
      File.readlines(@file).each do |line|
        next if line =~ /^(\#|\s*$)/

        # if we encounter 'puppet.your.domain' (the default value from a
        # fresh simp-bootstrap RPM), infer this is a freshly installed system
        # with no legitimate autosign entries.
        if line =~ /^puppet.your.domain/
          values = []
          break
        end
        values << line.strip
      end
      values
    end

    def recommended_value
      item = @config_items.fetch( 'hostname', nil )
      [ item.value ] if item
    end

    def validate_item item
      # FIXME: this is incomplete
      Simp::Cli::Config::Utils.validate_hostname( item ) ||
      Simp::Cli::Config::Utils.validate_fqdn( item ) ||
      Simp::Cli::Config::Utils.validate_ip( item ) ||
      item =~ /\*/
    end

    def apply
      say_green "Updating #{@file}..." if !@silent
      File.open(@file, 'w') do |file|
        file.puts "# You should place any hostnames/domains here that you wish to autosign.\n" +
                  "# The most security conscious method is to list each individual hostname:\n" +
                  "#   hosta.your.domain\n" +
                  "#   hostb.your.domain\n" +
                  "#\n" +
                  "# Wildcard domains work, but absolutely should NOT be used unless you fully\n" +
                  "# trust your network.\n" +
                  "#   *.your.domain\n\n"
        @current_value.values.each do |value|
          file.puts(value)
        end
      end
    end
  end
end
