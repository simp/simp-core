require File.expand_path( '../item',  File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end

module Simp::Cli::Config
  class Item::LdapBindPw < PasswordItem
    def initialize
      super
      @key         = 'ldap::bind_pw'
      @description = %Q{The LDAP bind password}
    end

    def validate string
      !string.to_s.strip.empty? && super
    end

    # LDAP Bind PW must known and stored in cleartext
    def encrypt string
      string
    end
  end
end
