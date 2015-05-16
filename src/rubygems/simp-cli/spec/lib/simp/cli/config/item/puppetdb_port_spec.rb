require 'simp/cli/config/item/puppetdb_port'
require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::PuppetDBPort do
  before :each do
    @ci = Simp::Cli::Config::Item::PuppetDBPort.new
    @ci.silent = true
  end

  describe "#validate" do
    it "validates proper port number" do
      expect( @ci.validate '8139' ).to eq true
    end

    it "doesn't validate nonsense" do
      expect( @ci.validate '0' ).to         eq false
      expect( @ci.validate '-1' ).to        eq false
      expect( @ci.validate '999999999' ).to eq false
      expect( @ci.validate 'fred' ).to      eq false
      expect( @ci.validate '' ).to          eq false
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end
