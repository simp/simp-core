require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::DHCP < Item
    def initialize
      super
      @key         = 'dhcp'
      @description = %q{Whether or not to use DHCP to set up your network ("static" or "dhcp")}
    end

    def recommended_value
      'static' # a puppet master is always recommended to be static.
    end

    def validate( x )
      return ['dhcp', 'static' ].include?( x.to_s.downcase )
    end

    def not_valid_message
      'Valid answers are "static" or "dhcp"'
    end
  end
end
