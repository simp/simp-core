require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::UseIPtables < YesNoItem
    def initialize
      super
      @key         = 'use_iptables'
      @description = %Q{Whether or not to use iptables on this system.

If there is code that calls the IPTables native type directly, this option may
not function properly.  We are looking into solutions for this issue.}
    end

    def recommended_value
      os_value || 'yes'
    end
  end
end
