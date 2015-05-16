require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::Hostname < Item
    def initialize
      super
      @key         = 'hostname'
      @description = %q{The FQDN of the system.}
      @fact        = 'fqdn'
    end

    def validate( x )
      Simp::Cli::Config::Utils.validate_fqdn x
    end

    def recommended_value
      validate( os_value ) ? os_value : 'puppet.change.me'
    end
  end
end
