require "resolv"
require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::RenameFqdnYaml < ActionItem
    attr_accessor :file

    def initialize
      super
      @key         = 'puppet::rename_fqdn_yaml'
      @description = %Q{Renames hieradata/hosts/puppet.your.domain.yaml (apply-only; noop).}
      @file        = '/etc/puppet/environments/production/hieradata/hosts/puppet.your.domain.yaml'
    end

    def apply
      result   = true
      fqdn     = @config_items.fetch( 'hostname' ).value
      new_file = File.join( File.dirname( @file ), "#{fqdn}.yaml" )
      say_green 'Moving default <domain>.yaml file' if !@silent

      if File.exists?(@file)
        if File.exists?( new_file )
          result = false
          diff   = `diff #{new_file} #{@file}`
          say_yellow "WARNING: #{File.basename( new_file )} exists, but the content differs from the original system content. Review and consider updating:\n#{diff}" if !diff.empty?
        else
          File.rename( @file, new_file )
        end
      else
        result = false
        say_yellow "WARNING: file not found: #{@file}"
      end
      true
    end
  end
end
