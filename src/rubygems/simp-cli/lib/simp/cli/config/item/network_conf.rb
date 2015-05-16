require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::NetworkConf < ActionItem
    def initialize
      super
      @key               = 'network::conf'
      @description       = 'action item; configures network interfaces'
      @die_on_apply_fail = true
    end

    def apply
      ci  = {}
      cmd = nil

      dhcp      = @config_items.fetch( 'dhcp'        ).value
      # BOOTPROTO=none is valid to spec; BOOTPROTO=static isn't
      bootproto = (dhcp == 'static') ? 'none' : dhcp
      interface = @config_items.fetch( 'network::interface'   ).value

      # apply the interface useing the SIMP classes
      # NOTE: the "FACTER_ipaddress=XXX" helps puppet avoid a fatal error that
      #       occurs in the core ipaddress fact on offline systems.
      cmd = %Q@FACTER_ipaddress=XXX puppet apply -e "network::add_eth{'#{interface}': bootproto => '#{bootproto}', onboot => 'yes'@

      if bootproto == 'none'
        ipaddress   = @config_items.fetch( 'ipaddress'   ).value
        hostname    = @config_items.fetch( 'hostname'    ).value
        netmask     = @config_items.fetch( 'netmask'     ).value
        gateway     = @config_items.fetch( 'gateway'     ).value
        dns_search  = @config_items.fetch( 'dns::search' ).value
        dns_servers = @config_items.fetch( 'dns::servers').value

        resolv_domain = hostname.split('.')[1..-1].join('.')
        cmd += %Q{, }
        cmd += %Q@ipaddr => '#{ipaddress}', @
        cmd += %Q@netmask => '#{netmask}', @
        cmd += %Q@gateway => '#{gateway}' } @
        cmd += %Q@class{ 'common::resolv': @
        cmd += %Q@resolv_domain => '#{resolv_domain}', @
        cmd += %Q@nameservers => #{ format_puppet_array( dns_servers ) }, @
        cmd += %Q@search => #{ format_puppet_array( dns_search ) }, @
        cmd += %Q@named_autoconf => false, @
      end
      cmd += %Q@}"@
# TODO: maybe good ideas
#   - set $::domain with FACTER_domain=
#   - set comon::resolv{ named_autofonf => false

      puts cmd unless @silent
      %x{#{cmd}}
    end

   def format_puppet_array v
     v = [v] if v.kind_of? String
     "['#{v.join "','"}']"
   end
  end
end
