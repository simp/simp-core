require 'simp/cli/config/item/gateway'
require 'rspec/its'
require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::Gateway do
  before :each do
    @ci = Simp::Cli::Config::Item::Gateway.new
  end

  describe "#validate" do
    it "validates plausible gateways" do
      expect( @ci.validate '192.168.1.0' ).to eq true
    end

    it "doesn't validate impossible gateways" do
      expect( @ci.validate nil ).to eq false
      expect( @ci.validate false ).to eq false
      expect( @ci.validate '999.999.999.999' ).to eq false
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end
