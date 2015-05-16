require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::IPAddress < Item
    def initialize
      super
      @key         = 'ipaddress'
      @description = 'The IP address of this system'
      @__warning   = false
    end


    # TODO: comment upon the hell-logic below
    # Config::Items are happiest when @fact if set and Facter returns a value
    #
    # But any Item that relies on the value of interface has a problem
    # in that facter can't know which ipaddress_* fact to query until the value
    # of interface is known.
    def os_value
      ip = nil
      nic = @config_items.fetch( 'network::interface' ).value
      if nic || @fact
        @fact = @fact || "ipaddress_#{nic}"
        ip = super
        if ip.nil? and !@__warning
          warning = "WARNING: #{@key}: No IP Address found for NIC #{nic}"
          say "<%= color(%q{#{warning}}, YELLOW) %>\n"
          @__warning = true
        end
      end
      ip
    end


    # Always recommend the configured IP
    def recommended_value; os_value; end


    def validate( x )
      Simp::Cli::Config::Utils.validate_ip x
    end
  end
end
