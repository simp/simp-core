require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::RsyncBase < Item
    def initialize
      super
      @key         = 'rsync::base'
      @description = <<-EOF.gsub(/^ {8}/,'')
        Several modules use rsync as a means of pulling down large
        collections of files. This provides a single point of configuration
        for the system defaults.

        Individual modules can be overridden as required.
      EOF
      if Facter.value('lsbmajdistrelease') < '7' then
        @base_dir = '/srv/rsync'
      else
        @base_dir = File.exists?( '/var/simp/' ) ? '/var/simp/rsync' : '/srv/simp/rsync'
        @base_dir = "#{@base_dir}/%{::operatingsystem}/%{::lsbmajdistrelease}"
      end
    end

    def os_value; nil; end

    def validate( x )
      x =~ %r{^/} ? true : false
    end

    def recommended_value
      "#{@base_dir}"
    end
  end
end
