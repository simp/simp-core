require "resolv"
require 'highline/import'
require File.expand_path( '../item',  File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::LogServers < ListItem
    def initialize
      super
      @key         = 'log_servers'
      @description = %Q{Your log server(s). Only use hostnames here if at all possible.}
      @allow_empty_list = true
    end

    def os_value
      nil
    end

    def recommended_value
      if @config_items.key? 'hostname'
        [ @config_items.fetch('hostname').value ]
      else
        nil
      end
    end

    def validate_item item
      ( Simp::Cli::Config::Utils.validate_hostname( item ) ||
        Simp::Cli::Config::Utils.validate_fqdn( item ) ||
        Simp::Cli::Config::Utils.validate_ip( item ) )
    end
  end
end
