require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::PuppetConf < ActionItem
    attr_accessor :file

    def initialize
      super
      @key         = 'puppet::conf'
      @description = 'silent item; configures /etc/puppet/puppet.conf'
      # FIXME: this path will change with Puppet Enterprise; should this autodetect?
      @file        = '/etc/puppet/puppet.conf'
    end

    # NOTE: This is (mostly) lifted straight from the old simp config
    # TODO: refactor sed statements to pure ruby,
    #       consider using IO handles instead of File.open (easier to test in memory)?
    #       or use Puppet::Settings ( https://github.com/puppetlabs/puppet/blob/master/lib/puppet/settings.rb )?
    def apply
      say_green "Updating #{@file}..." if !@silent
      if @skip_apply
        say_yellow "WARNING: directed to skip Puppet configuration of #{file}" if !@silent
        return
      end

      backup_file = "#{@file}.pre_simpconfig"
      FileUtils.cp("#{@file}", backup_file)
      `sed -i '/^\s*server.*/d'          #{@file}`
      `sed -i '/.*trusted_node_data.*/d' #{@file}`
      `sed -i '/.*digest_algorithm.*/d'  #{@file}`
      `sed -i '/.*stringify_facts.*/d'   #{@file}`
      `sed -i '/.*environment_path.*/d'  #{@file}`
      `sed -i '/^.main./ a \\    trusted_node_data = true\'   #{@file}`
      `sed -i '/^.main./ a \\    digest_algorithm  = sha256\' #{@file}`
      `sed -i '/^.main./ a \\    stringify_facts   = false\'  #{@file}`
      `sed -i '/^.main./ a \\    environmentpath   = /etc/puppet/environments\' #{@file}`
      `sed -i '/trusted_node_data/ a \\    server            = #{@config_items.fetch( 'puppet::server' ).value}\' #{@file}`


      # do not die if config items aren't found
      puppet_server  = 'puppet.change.me'
      puppet_ca      = 'puppetca.change.me'
      puppet_ca_port = '8141'
      if item = @config_items.fetch( 'puppet::server', nil )
        puppet_server  = item.value
      end
      if item = @config_items.fetch( 'puppet::ca', nil )
        puppet_ca      = item.value
      end
      if item = @config_items.fetch( 'puppet::ca_port', nil )
        puppet_ca_port = item.value
      end


      puppet_conf = File.readlines(@file)
      File.open("#{@file}", 'w') do |out_file|
        line_check = {
          'server'    => false,
          'ca_server' => false,
          'ca_port'   => false
        }
        puppet_conf.each do |line|
          if line !~ /^\s*(#{line_check.keys.join('|')})(\s*=\s*)/
            out_file.puts line
          else
            $1.chomp
            line_check[$1] = true
            case $1
              when 'server' then
                out_file.puts "    #{$1}#{$2}#{puppet_server}"
              when 'ca_server' then
                out_file.puts "    #{$1}#{$2}#{puppet_ca}"
              when 'ca_port' then
                out_file.puts "    #{$1}#{$2}#{puppet_ca_port}"
            end
          end
        end
        line_check.keys.each do |key|
          if not line_check[key] then
            case key
              when 'server' then
                out_file.puts "    server    = #{puppet_server}"
              when 'ca_server' then
                out_file.puts "    ca_server = #{puppet_ca}"
              when 'ca_port' then
                out_file.puts "    ca_port   = #{puppet_ca_port}"
            end
          end
        end
      end

    end
  end
end
