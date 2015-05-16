require 'highline/import'
require 'puppet'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::PuppetCA < Item
    def initialize
      super
      @key         = 'puppet::ca'
      @description = 'The Puppet Certificate Authority'
    end

    def os_value
      Puppet.settings.setting( 'ca_server' ).value
    end

    def validate( x )
      Simp::Cli::Config::Utils.validate_hostname( x ) ||
      Simp::Cli::Config::Utils.validate_fqdn( x ) ||
      Simp::Cli::Config::Utils.validate_ip( x )
    end

    def recommended_value
      item = @config_items.fetch( 'hostname', nil )
      item.value if item
    end
  end
end
