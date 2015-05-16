require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::LdapSyncDn < Item
    def initialize
      super
      @key         = 'ldap::sync_dn'
      @description = %Q{}
    end

    def validate( x )
      (x.to_s =~ /^cn=/) ? true : false
    end

    def recommended_value
      "cn=LDAPSync,ou=Hosts,%{hiera('ldap::base_dn')}"
    end

  end
end
