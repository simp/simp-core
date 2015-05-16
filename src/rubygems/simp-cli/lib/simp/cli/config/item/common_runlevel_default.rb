require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::CommonRunLevelDefault < Item
    def initialize
      super
      @key         = 'common::runlevel'
      @description = %Q{The default system runlevel (1-5).}
    end

    def validate( x )
      (x.to_s =~ /\A[1-5]\Z/) ? true : false
    end

    def not_valid_message
      'Must be a number between 1 and 5'
    end

    def os_value
      # FIXME: Facter fact
      %x{runlevel | awk '{print $2}'}.strip
    end

    def recommended_value
      '3'
    end
  end
end
