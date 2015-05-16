require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end

module Simp::Cli::Config
  class Item::PuppetDBPort < Item
    def initialize
      super
      @key         = 'puppetdb::master::config::puppetdb_port'
      @description = %Q{The PuppetDB server port number}
      @value       = recommended_value
    end

    def recommended_value
      '8139'
    end

    def validate string
      ( string =~ /^\d+$/ ? true : false ) &&
      ( string.to_i > 1 && string.to_i < 65536 )
    end
  end
end
