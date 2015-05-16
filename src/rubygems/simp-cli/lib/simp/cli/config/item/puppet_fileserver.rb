require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::PuppetFileServer < ActionItem

    attr_accessor :file

    def initialize
      super
      @key         = 'puppet::fileserver'
      @description = 'silent item; configures /etc/puppet/fileserver.conf'
      @file        = '/etc/puppet/fileserver.conf'
    end

    def apply
      say_green "  updating Puppet configurations in #{@file}..." if !@silent

      conf = @file

      require 'fileutils'
      FileUtils.cp(conf, "#{conf}.pre_simpconfig")

      hostname = @config_items.fetch( 'hostname' ) #FIXME: should this be hostname or puppet_server?
      domain = hostname.value.split('.')[1..-1].join('.')

      if !domain or domain.empty?
        raise "Could not determine domain from hostname '#{hostname}"
      end

      default_entries = ['facts','plugins','keydist','cacerts','mcollective']

      fileserver_default = <<-EOM
        [facts]
          path /etc/puppet/facts
          allow *.#{domain}

        [plugins]
          allow *.#{domain}

        [keydist]
          path /etc/puppet/keydist/%H
          allow *.#{domain}

        [cacerts]
          path /etc/puppet/keydist/cacerts
          allow *.#{domain}

        [mcollective]
          path /etc/puppet/keydist/mcollective
          allow *.#{domain}
      EOM

      # Complete crib from StackOverflow
      fileserver_default.gsub!(/^#{fileserver_default[/\A\s*/]}/,'')

      fileserver_new = []

      fileserver_old = File.read(conf).split("\n")

      # Preserve any beginning comments
      while fileserver_old[0] =~ /^\s*(#.*|\s*)$/ do
        fileserver_new << fileserver_old.shift
      end

      # Add in our defaults
      fileserver_new << fileserver_default

      # Read the rest of the file, ignoring any section that we're going to
      # replace.
      key = nil
      comments = []
      fileserver_old.each do |line|
        if line =~ /\[(.*)\]/ then
          key = $1.strip
          comments = []
        end

        next if default_entries.include?(key)

        fileserver_new << line
      end

      # If the last entry was a default entry key, preserve the trailing file
      # comments (if any)
      if default_entries.include?(key) then
        fileserver_new << "\n"
        fileserver_new += comments
      end

      # Smash duplicates
      fileserver_new.each_with_index do |x,i|
        fileserver_new.delete(i) unless fileserver_new[i] != fileserver_new[i + 1]
      end

      File.open(conf,'w'){|x| x.puts(fileserver_new.join("\n"))}

      true
    end
  end
end
