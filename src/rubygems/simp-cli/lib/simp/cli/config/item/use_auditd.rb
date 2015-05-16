require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::UseAuditd < YesNoItem
    def initialize
      super
      @key         = 'use_auditd'
      @description = %q{Whether or not to use auditd on this system.}
    end

    def recommended_value
      os_value || 'yes'
    end
  end
end
