require 'simp/cli/config/item/netmask'
require 'rspec/its'
require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::Netmask do
  before :each do
    @ci = Simp::Cli::Config::Item::Netmask.new
  end

  describe "#validate" do
    it "validates netmasks" do
      expect( @ci.validate '255.255.255.0' ).to eq true
      expect( @ci.validate '255.254.0.0' ).to eq true
      expect( @ci.validate '192.0.0.0' ).to eq true
    end

    it "doesn't validate bad netmasks" do
      expect( @ci.validate '999.999.999.999' ).to eq false
      expect( @ci.validate '255.999.0.0' ).to eq false
      expect( @ci.validate '255.0.255.0' ).to eq false
      expect( @ci.validate '0.255.0.0' ).to eq false
      expect( @ci.validate nil ).to eq false
      expect( @ci.validate false ).to eq false
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end
