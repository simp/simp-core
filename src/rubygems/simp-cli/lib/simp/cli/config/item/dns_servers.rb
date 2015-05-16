require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::DNSServers < ListItem
    attr_accessor :file
    def initialize
      super
      @key         = 'dns::servers'
      @description = %Q{A list of DNS servers for the managed hosts.

        If the first entry of this list is set to '127.0.0.1', then
        all clients will configure themselves as caching DNS servers
        pointing to the other entries in the list.

        If you have a system that's including the 'named' class and
        is *not* in this list, then you'll need to set a variable at
        the top of that node entry called $named_server to 'true'.
        This will get around the convenience logic that was put in
        place to handle the caching entries and will not attempt to
        convert your system to a caching DNS server. You'll know
        that you have this situation if you end up with a duplicate
        definition for File['/etc/named.conf'].}.gsub(/^ +/, '')
      @file = '/etc/resolv.conf'
    end

    def os_value
      # TODO: make this a custom fact?
      File.readlines( @file ).select{ |x| x =~ /^nameserver\s+/ }.map{ |x| x.gsub( /nameserver\s+(.*)\s*/, '\\1' ) }
    end

    # recommend:
    #   - os_value  when present, or:
    #   - ipaddress when present, or:
    #   - a must-change value
    def recommended_value
      os = os_value
      if os.empty?
        if ip = @config_items.fetch( 'ipaddress', nil )
          [ip.value]
        else
          ['8.8.8.8 (change this)']
        end
      else
        os
      end
    end

    # Each DNS server should be a valid IP address
    def validate_item item
      Simp::Cli::Config::Utils.validate_ip item
    end
  end
end
