require 'highline/import'
require 'puppet'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::PuppetServer < Item
    def initialize
      super
      @key         = 'puppet::server'
      @description = %q{The Hostname or FQDN of the puppet server.}
#      @fact        = 'fqdn'
    end

    def os_value
      Puppet.settings.setting( 'server' ).value
    end

    def validate( x )
      Simp::Cli::Config::Utils.validate_hostname( x ) ||
      Simp::Cli::Config::Utils.validate_fqdn( x )
    end

    def recommended_value
      item = @config_items.fetch( 'hostname', nil )
      item.value if item
    end
  end
end
