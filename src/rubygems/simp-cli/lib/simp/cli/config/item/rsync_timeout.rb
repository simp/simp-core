require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::RsyncTimeout < Item
    def initialize
      super
      @key         = 'rsync::timeout'
      @description = 'maximum rsync timeout in seconds.  0 = no timeout'
      @skip_query  = true
    end

    def os_value; nil; end

    def validate( x )
      x.to_s =~ %r{^\d+} ? true : false
    end

    def recommended_value
      '1'
    end
  end
end
