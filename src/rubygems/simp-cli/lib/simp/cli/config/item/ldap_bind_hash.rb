require 'highline/import'
require File.expand_path( '../item',  File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::LdapBindHash < Item
    def initialize
      super
      @key         = 'ldap::bind_hash'
      @description = %Q{The salted LDAP bind password hash}
      @skip_query  = true
    end

    def recommended_value
      encrypt( @config_items.fetch( 'ldap::bind_pw' ).value )
    end

    def encrypt( string, salt=nil )
      Simp::Cli::Config::Utils.encrypt_openldap_hash( string, salt )
    end

    def validate( x )
      Simp::Cli::Config::Utils.validate_openldap_hash( x )
    end
  end
end
