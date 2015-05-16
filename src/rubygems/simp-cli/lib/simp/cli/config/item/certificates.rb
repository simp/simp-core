require "resolv"
require 'highline/import'
require File.expand_path( '../item',  File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::Certificates < ActionItem
    attr_accessor :dirs
    def initialize
      super
      @key         = 'certificates'
      @description = %Q{Sets up the cerificates for SIMP on apply. (apply-only; noop)}
      @dirs        = {
        :keydist => '/etc/puppet/environments/production/keydist',
        :fake_ca => '/etc/puppet/environments/production/FakeCA',
      }
      @die_on_apply_fail = true
    end


    def apply
      # Certificate Management
      say_green 'Checking system certificates...' if !@silent
      hostname = @config_items.fetch( 'hostname' ).value

      if !(
        File.exist?("#{@dirs[:keydist]}/#{hostname}/#{hostname}.pub") &&
        File.exist?("#{@dirs[:fake_ca]}/#{hostname}/#{hostname}.pem")
      )
        say_green "INFO: No certificates were found for '#{hostname}, generating..." if !@silent
        Simp::Cli::Config::Utils.generate_certificates([hostname], @dirs[:fake_ca])
      else
        say_yellow "WARNING: Found existing certificates for #{hostname}, not recreating" if !@silent
      end
    end
  end
end
