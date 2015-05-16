require "resolv"
require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  # FIXME: what is this for?
  class Item::LdapUri < ListItem
    def initialize
      super
      @key         = 'ldap::uri'
      @description = %Q{List of OpenLDAP servers in URI form (ldap://server)}
    end


    def os_value
      values = `grep URI /etc/openldap/ldap.conf`.split("\n").map do |line|
        line =~ /^\s*URI\s+(.+)\s*/
        $1
      end.compact
      values
    end


    def recommended_value
      if item = @config_items.fetch( 'hostname', nil )
        [ "ldap://#{item.value}" ]
      end
    end


    def validate_item item
      ( item =~ %r{^ldap://.+} ) ? true : false &&
      (
        Simp::Cli::Config::Utils.validate_hostname( item ) ||
        Simp::Cli::Config::Utils.validate_fqdn( item )     ||
        Simp::Cli::Config::Utils.validate_ip( item )
      )
    end
  end
end
