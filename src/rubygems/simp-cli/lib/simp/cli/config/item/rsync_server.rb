require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::RsyncServer < Item
    attr_accessor :file
    def initialize
      super
      @key         = 'rsync::server'
      @description = 'rsync server (usually the primary puppet master)'
      @__warning   = false
      @file = '/etc/rsyncd.conf'
    end

    def os_value
      if File.readable?(@file)
        res = File.readlines(@file).grep( /address\s*=/ ){|x| x.split('=').last.strip}
        res.empty? ? nil : res.first
      else
        # only show the FIRST warning
        if !@__warning
          warning = "WARNING: cannot read #{file}"
          say "<%= color(%q{#{warning}}, YELLOW) %>\n" unless @silent
          @__warning = true
        end
        nil
      end
    end

    def recommended_value
      os_value || '127.0.0.1'
    end

    def validate item
      ( Simp::Cli::Config::Utils.validate_ip( item ) ||
        Simp::Cli::Config::Utils.validate_fqdn( item ) ||
        Simp::Cli::Config::Utils.validate_hostname( item ) )
    end
  end
end
