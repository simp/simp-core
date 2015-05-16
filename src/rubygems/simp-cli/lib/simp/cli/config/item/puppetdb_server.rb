require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end

module Simp::Cli::Config
  class Item::PuppetDBServer < Item
    def initialize
      super
      @key         = 'puppetdb::master::config::puppetdb_server'
      @description = %Q{The dns name or ip of the puppetdb server}
      @value       = recommended_value
    end

    def recommended_value
      "%{hiera('puppet::server')}"
    end

    def validate string
      Simp::Cli::Config::Utils.validate_fqdn( string ) ||
      Simp::Cli::Config::Utils.validate_ip( string )   ||
      Simp::Cli::Config::Utils.validate_hiera_lookup( string )
    end
  end
end
