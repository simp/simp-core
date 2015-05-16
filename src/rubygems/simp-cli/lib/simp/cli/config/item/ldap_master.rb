require "resolv"
require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::LdapMaster < Item
    def initialize
      super
      @key         = 'ldap::master'
      @description = %Q{This is the LDAP master in URI form (ldap://server)}
    end

    def recommended_value
      if item = @config_items.fetch( 'hostname', nil )
        "ldap://#{item.value}"
      end
    end

    def validate item
      result = false
      if ( item =~ %r{^ldap://.+} ) ? true : false
        i = item.sub( %r{^ldap://}, '' )
        result = ( Simp::Cli::Config::Utils.validate_hostname( i ) ||
                   Simp::Cli::Config::Utils.validate_fqdn( i )     ||
                   Simp::Cli::Config::Utils.validate_ip( i ) )
      end
      result
    end
  end
end
