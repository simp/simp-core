require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::PuppetServerIP < Item
    def initialize
      super
      @key         = 'puppet::server::ip'
      @description = %Q{The Puppet server's IP address.\nThis is used to configure /etc/hosts properly.}
    end


    # Always recommend the configured IP
    def recommended_value
      @config_items.fetch( 'ipaddress' ).value
    end


    def validate( x )
      Simp::Cli::Config::Utils.validate_ip x
    end
  end
end
