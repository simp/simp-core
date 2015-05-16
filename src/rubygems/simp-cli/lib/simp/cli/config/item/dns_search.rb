require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::DNSSearch < ListItem
    attr_accessor :file
    def initialize
      super
      @key         = 'dns::search'
      @description = %Q{The DNS domain search string.\nRemember to put these in the appropriate order for your environment!}
      @file        = '/etc/resolv.conf'
    end

    def os_value
      # TODO: make this a custom fact?
      # NOTE: the resolver only uses the last of multiple search declarations
      File.readlines( @file ).select{ |x| x =~ /^search\s+/ }.last.to_s.gsub( /\bsearch\s+/, '').split( /\s+/ )
    end

    # recommend:
    #   - os_value  when present, or:
    #   - ipaddress when present, or:
    #   - a must-change value
    def recommended_value
      os = os_value
      if os.empty?
        if fqdn = @config_items.fetch( 'hostname', nil )
          [fqdn.value.split('.')[1..-1].join('.')]
        else
          ['domain.name (change this)']
        end
      else
        os
      end
    end

    # Each item must be a valid dns domain
    # TODO: def validate should notice if the search string will contain > 6
    # items or 256 chars
    def validate_item item
      # return false if !fqdn.is_a? String
      Simp::Cli::Config::Utils.validate_fqdn item
    end
  end
end
