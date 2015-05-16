require 'highline/import'
require 'puppet'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::PuppetCAPort < Item
    def initialize
      super
      @key         = 'puppet::ca_port'
      @description = 'The port which the Puppet CA will listen on (8141 by default).'
    end

    def os_value
      Puppet.settings.setting( 'ca_port' ).value
    end

    def validate( x )
       (x.to_s =~ /^\d+$/ ? true : false ) && x.to_i > 0 && x.to_i <= 65535
    end

    def recommended_value
      8141
    end
  end
end
