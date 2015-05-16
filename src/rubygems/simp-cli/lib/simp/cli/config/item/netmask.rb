require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::Netmask < Item
    def initialize
      super
      @key         = 'netmask'
      @description = %q{The netmask of the system.}
      @__warning   = false
    end

    def validate( x )
      Simp::Cli::Config::Utils.validate_netmask x
    end

    # TODO: comment upon the hell-logic below
    # TODO: possibly refactor ip and netmask os_value into shared parent
    def os_value
      netmask = nil
      nic = @config_items.fetch('network::interface').value
      if nic || @fact
        @fact = @fact || "netmask_#{nic}"
        netmask = super
        if netmask.nil? and !@__warning
          warning = "WARNING: #{@key}: No Netmask found for NIC #{nic}"
          say "<%= color(%q{#{warning}}, YELLOW) %>\n"
          @__warning = true
        end
      end
      netmask
    end

    def recommended_value; os_value; end
  end
end
