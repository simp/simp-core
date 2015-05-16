require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::UseLdap < YesNoItem
    def initialize
      super
      @key         = 'use_ldap'
      @description = %Q{Whether or not to use LDAP on this system.\nIf you disable this, modules will not attempt to use LDAP where possible.}
    end

    def recommended_value
      os_value || 'yes'
    end
  end
end
