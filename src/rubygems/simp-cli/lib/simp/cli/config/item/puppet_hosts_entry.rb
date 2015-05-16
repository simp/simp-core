require "resolv"
require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::PuppetHostsEntry < ActionItem
    attr_accessor :file

    def initialize
      super
      @key         = 'puppet::hosts_entry'
      @description = %Q{Ensures an entry for the puppet server in /etc/hosts (apply-only; noop).}
      @file        = '/etc/hosts'
    end

    def apply
      puppet_server    = @config_items.fetch( 'puppet::server' ).value
      puppet_server_ip = @config_items.fetch( 'puppet::server::ip' ).value
      status = false

      say_green "Updating #{@file}..." if !@silent

      values = Array.new
      File.readlines(@file).each do |line|
        next if line =~ /\s*#/
        next if line =~ /#{puppet_server}/ and @value.eql?(puppet_server)
        next if line =~ /localdomain/
        next if line =~ /localdomain6/
        next if line =~ /\spuppet(\s|$)/  # remove alias 'puppet'
        values.push(line)
      end
      File.open(@file,'w') {|fh|
        fh.puts('127.0.0.1 localhost localhost.localdomain localhost4 localhost4.localdomain4')
        fh.puts('::1 localhost localhost.localdomain localhost6 localhost6.localdomain6')
        fh.puts("#{puppet_server_ip} #{puppet_server} #{puppet_server.split('.').first}")
        fh.puts(values)
      }
      true
    end
  end
end
