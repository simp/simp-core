require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config

  class Item::NetworkInterface < Item
    def initialize
      super
      @key         = 'network::interface'
      @description = 'The network interface to use to connect to the network.'
    end

    # try to guess which NIC is likely to be used
    # TODO IDEA: also use Facter to prefer NICs that already have IPs
    def recommended_value
      devices = acceptable_values
      (
       devices.select{|x|  x.match(/^br/)}.first  ||
       devices.select{|x|  x.match(/^eth/)}.first ||
       devices.select{|x| x.match(/^em/)}.first   ||
       devices.first
      )
    end

    def validate( x )
      acceptable_values.include?( x )
    end

    def not_valid_message
      "Acceptable values: \n" + acceptable_values.map{ |x| "  #{x}" }.join("\n")
    end

    # helper method; provides a list of available NICs
    def acceptable_values
      Facter.value('interfaces').split(',').delete_if{|x| x == 'lo'}.sort
    end
  end
end
