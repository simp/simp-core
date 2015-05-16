require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::Gateway < Item
    def initialize
      super
      @key         = 'gateway'
      @description = 'The default gateway.'
      @__warning   = false
    end


    # FIXME: make this a custom Fact?
    def os_value
      `ip route show` =~ /default\s*via\s*(.*)\s*dev/
      (($1 && $1.strip) || nil)
    end


    # Always recommend the default Gateway
    # TODO IDEA: recommend the primary nic's gateway?
    def recommended_value; os_value; end


    def validate( x )
      Simp::Cli::Config::Utils.validate_ip x
    end
  end
end
