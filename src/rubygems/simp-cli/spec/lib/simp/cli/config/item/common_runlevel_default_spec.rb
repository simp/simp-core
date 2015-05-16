require 'simp/cli/config/item/common_runlevel_default'
require 'rspec/its'
require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::CommonRunLevelDefault do
  before :each do
    @ci = Simp::Cli::Config::Item::CommonRunLevelDefault.new
  end

  describe "#validate" do
    it "validates common_runlevel_defaults" do
      expect( @ci.validate '1' ).to eq true
      expect( @ci.validate '3' ).to eq true
      expect( @ci.validate '5' ).to eq true
    end

    it "doesn't validate bad common_runlevel_defaults" do
      expect( @ci.validate '' ).to eq false
      expect( @ci.validate '0' ).to eq false
      expect( @ci.validate '7' ).to eq false
      expect( @ci.validate nil ).to eq false
      expect( @ci.validate false ).to eq false
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end
