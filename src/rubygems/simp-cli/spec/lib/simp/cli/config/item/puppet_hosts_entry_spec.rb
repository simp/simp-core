require 'simp/cli/config/item/puppet_hosts_entry'
require 'simp/cli/config/item/puppet_server'
require 'simp/cli/config/item/puppet_server_ip'
require 'rspec/its'
require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::PuppetHostsEntry do
  before :all do
    @ci        = Simp::Cli::Config::Item::PuppetHostsEntry.new
    @ci.silent = true   # turn off command line summary on stdout
    @files_dir = File.expand_path( 'files', File.dirname( __FILE__ ) )
    @tmp_dir   = File.expand_path( 'tmp', File.dirname( __FILE__ ) )
  end

  describe "#apply" do
    before :context do
      @tmp_file        = File.join( @tmp_dir, 'test__hosts' )
      @file            = File.join( @files_dir,'hosts')
      @ci.file         = @tmp_file

      item             = Simp::Cli::Config::Item::PuppetServerIP.new
      item.value       = '1.2.3.4'
      @ci.config_items[item.key] = item

      item             = Simp::Cli::Config::Item::PuppetServer.new
      item.value       = 'puppet.domain.tld'
      @ci.config_items[item.key] = item
    end

    context "with a fresh hosts file" do
      before :context do
        FileUtils.mkdir_p   @tmp_dir
        FileUtils.copy_file @file, @tmp_file

        @result = @ci.apply
      end

      it "configures hosts with the correct values" do
        lines = File.readlines( @tmp_file ).join( "\n" )
        expect( lines ).to match(%r{\bpuppet.domain.tld\b})
      end

      it "reports success" do
        expect( @result ).to eq true
      end

      after :context do
        FileUtils.rm @tmp_file
      end
    end


    context "with an existing hosts file" do
      before :context do
        FileUtils.mkdir_p   @tmp_dir
        FileUtils.copy_file @file, @tmp_file

        @result = @ci.apply
      end

      it "configures hosts with the correct values" do
        lines = File.readlines( @tmp_file ).join( "\n" )
        expect( lines ).to match(%r{\bpuppet.domain.tld\b})
      end

      it "replaces puppet host/aliases with the correct values" do
        lines = File.readlines( @tmp_file ).each do |line|
          expect( line ).to_not match(%r{\bpuppet.example.com\b})
        end
      end

      it "reports success" do
        expect( @result ).to eq true
      end

      after :context do
        FileUtils.rm @tmp_file
      end
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like "a child of Simp::Cli::Config::Item"
end

