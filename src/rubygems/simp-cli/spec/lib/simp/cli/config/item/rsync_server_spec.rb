require 'simp/cli/config/item/rsync_server'
require 'rspec/its'
require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::RsyncServer do
  before :each do
    @files_dir   = File.expand_path( 'files', File.dirname( __FILE__ ) )
    @ci          = Simp::Cli::Config::Item::RsyncServer.new
    @ci.silent   = true
  end

  describe "#validate" do
    it "validates a good rsync server" do
      expect( @ci.validate 'puppet.simp.dev' ).to eq true
      expect( @ci.validate '127.0.0.1' ).to eq true
    end

    it "doesn't validate nonsense" do
      expect( @ci.validate '..' ).to eq false
    end
  end

  describe "os_value" do
    it "reads address from rsyncd.conf file" do
      @ci.file = File.join( @files_dir, 'rsyncd.conf' )
      expect( @ci.os_value ).to eq '127.0.0.1'
    end

    it "returns nil if file does not contain address" do
      @ci.file = '/dev/null'
      expect( @ci.os_value ).to be_falsey
    end

    it "returns nil if file is not readable" do
      @ci.file = '/proc/nonsense/blahblahblah/.........'
      expect( @ci.os_value ).to be_falsey
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end
