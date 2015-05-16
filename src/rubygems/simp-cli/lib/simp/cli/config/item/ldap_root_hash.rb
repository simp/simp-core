require 'highline/import'
require File.expand_path( '../item',  File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::LdapRootHash < PasswordItem
    def initialize
      super
      @key                 = 'ldap::root_hash'
      @description         = %Q{The LDAP root password hash.

        If you set this with simp config, type the password and the hash will be
        generated for you.' }.gsub( /^\s{8}/, '' )
      @generate_by_default = false
    end

    def os_value
      if File.readable?('/etc/openldap/slapd.conf')
        `grep rootpw /etc/openldap/slapd.conf` =~ /\Arootpw\s+(.*)\s*/
        $1
      end
    end

    def encrypt( string, salt=nil )
      Simp::Cli::Config::Utils.encrypt_openldap_hash( string, salt )
    end

    def validate( x )
      Simp::Cli::Config::Utils.validate_openldap_hash( x ) ||
        ( !x.to_s.strip.empty? && super )
    end
  end
end
