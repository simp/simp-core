require 'simp/cli/config/item/rename_fqdn_yaml'
require 'simp/cli/config/item/hostname'
require 'rspec/its'
require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::RenameFqdnYaml do
  before :all do
    @ci        = Simp::Cli::Config::Item::RenameFqdnYaml.new
    @ci.silent = true   # turn off command line summary on stdout
  end

  context "when ensuring the hosts entry" do
    before :context do
      @files_dir       = File.expand_path( 'files', File.dirname( __FILE__ ) )
      @tmp_dir         = File.expand_path( 'tmp', File.dirname( __FILE__ ) )
      @file            = File.join( @files_dir,'puppet.your.domain.yaml')
      @tmp_file        = File.join( @tmp_dir, 'temp__puppet.your.domain.yaml' )
      @ci.file         = @tmp_file

      @fqdn            = 'hostname.domain.tld'
      item             = Simp::Cli::Config::Item::Hostname.new
      item.value       = @fqdn
      @ci.config_items[item.key] = item
      @new_file        = File.join( @tmp_dir, "#{@fqdn}.yaml" )
    end


    context "when moving the yaml file" do
      before :context do
        [@tmp_file, @new_file].each do |file|
          FileUtils.rm file if File.exists? file
        end

        FileUtils.mkdir_p   @tmp_dir
        FileUtils.copy_file @file, @tmp_file

        @result = @ci.apply
      end

      it "places a file in the correct location" do
        expect( File ).to exist( @new_file )
      end

      it "doesn't leave a file in the old location" do
        expect( File ).not_to exist( @tmp_file )
      end

      it "reports success" do
        expect( @result ).to eq true
      end

      after :context do
        [@tmp_file, @new_file].each do |file|
          FileUtils.rm file if File.exists? file
        end
      end
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like "a child of Simp::Cli::Config::Item"
end

