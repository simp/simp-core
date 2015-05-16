require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SetupNIC < YesNoItem
    def initialize
      super
      @key         = 'network::setup_nic'
      @description = %Q{Do you want to activate this NIC now?}
    end

    def recommended_value
      os_value || 'yes'
    end

    def query_ask
      # TODO: check, then
      # The NIC does not currently have an IP, Netmask, or Gateway
      nic = @config_items.fetch('network::interface').value
#      @description.gsub( 'this NIC'
      super
    end

  end
end
