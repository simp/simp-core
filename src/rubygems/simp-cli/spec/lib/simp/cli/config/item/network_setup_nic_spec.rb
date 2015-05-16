require 'simp/cli/config/item/network_setup_nic'
require 'rspec/its'
require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::SetupNIC do
  before :each do
    @ci = Simp::Cli::Config::Item::SetupNIC.new
  end

  describe "#validate" do
    it "validates yes/no" do
      expect( @ci.validate 'yes' ).to eq true
      expect( @ci.validate 'y'   ).to eq true
      expect( @ci.validate 'Y'   ).to eq true
      expect( @ci.validate 'no'  ).to eq true
      expect( @ci.validate 'n'   ).to eq true
      expect( @ci.validate 'NO'  ).to eq true
      expect( @ci.validate true  ).to eq true
      expect( @ci.validate false ).to eq true
    end

    it "doesn't validate other things" do
      expect( @ci.validate 'ydd'  ).to eq false
      expect( @ci.validate 'gsdg' ).to eq false
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end
