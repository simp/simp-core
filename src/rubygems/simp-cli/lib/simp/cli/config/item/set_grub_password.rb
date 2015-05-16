require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SetGrubPassword < YesNoItem
    def initialize
      super
      @key         = 'set_grub_password'
      @description = %Q{Whether or not to set the GRUB password on this system.}
    end

    def recommended_value
      os_value || 'yes'
    end
  end
end
