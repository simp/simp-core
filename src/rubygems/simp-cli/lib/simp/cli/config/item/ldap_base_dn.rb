require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::LdapBaseDn < Item
    def initialize
      super
      @key         = 'ldap::base_dn'
      @description = %Q{The Base DN of the LDAP server}
    end


    def os_value
      # TODO: turn into custom fact?
      result = nil
      if File.readable?('/etc/openldap/ldap.conf') &&
         `grep BASE /etc/openldap/ldap.conf` =~ /^\s*BASE\s+(\S+)\s*/
        result = $1
      end
      result
    end


    def recommended_value
      if item = @config_items.fetch( 'hostname', nil )
        item.value.split('.')[1..-1].map{ |domain| "dc=#{domain}" }.join(',')
      end
    end


    def validate( x )
      (x.to_s =~ /^dc=/) ? true : false
    end
  end
end
