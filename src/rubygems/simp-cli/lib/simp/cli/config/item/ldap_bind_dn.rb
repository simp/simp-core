require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::LdapBindDn < Item
    def initialize
      super
      @key         = 'ldap::bind_dn'
      @description = %Q{LDAP Bind Distinguished Name}
    end


    def os_value
      # TODO: turn into custom fact?
      if File.readable?('/etc/openldap/ldap.conf') &&
        `grep BINDDN /etc/openldap/ldap.conf` =~ /\ABINDDN\s+(\S+)\s*/
        $1
      end
    end


    def validate( x )
      (x.to_s =~ /^cn=/) ? true : false
    end


    def recommended_value
      "cn=hostAuth,ou=Hosts,%{hiera('ldap::base_dn')}"
    end
  end
end
