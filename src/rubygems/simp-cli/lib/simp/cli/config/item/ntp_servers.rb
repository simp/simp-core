require "resolv"
require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::NTPServers < ListItem
    def initialize
      super
      @key         = 'ntpd::servers'
      @description =  %Q{Your network's NTP time servers.}
      @description += %Q{\n\nNOTE: a consistent time source is critical to yours systems' security.}
      @description += %Q{\nDO NOT run multiple production systems using individual hardware clocks!}
      @allow_empty_list = true

      @extra_description = ''
    end

    def decription
      "#{@description}#{@extra_description}"
    end

    def os_value( file='/etc/ntp/ntpservers' )
      # TODO: make this a custom fact?
      # TODO: is /etc/ntp/ntpservers being used in recent versions of SIMP?
      servers = []
      if File.readable? file
        File.readlines( file ).map do |line|
          line.strip!
          if line !~ /^#/
            servers << line
          else
            nil
          end
        end.compact
      end
      servers
    end

    def recommended_value
      @extra_description = ''
      if (!os_value.empty?) && (os_value.first !~ /^127\./)
        os_value
      elsif @config_items.key? 'gateway'
        gateway  = @config_items.fetch('gateway').value
        @extra_description = %{\n(In many networks, the default gateway provides an NTP server}
        [ gateway ]
      else
        nil
      end
    end

    def validate_item item
      ( Simp::Cli::Config::Utils.validate_ip( item ) ||
        Simp::Cli::Config::Utils.validate_fqdn( item ) )
    end
  end
end
