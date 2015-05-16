require 'simp/cli/config/item/network_interface'
require 'rspec/its'
require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::NetworkInterface do
  before :each do
    @ci = Simp::Cli::Config::Item::NetworkInterface.new
  end

  describe "#initialize" do
    subject{ @ci }
    its(:key){ is_expected.to eq( 'network::interface') }
  end

  describe "#validate" do
    subject{ @ci }
    it "doesn't validate nonsensical interfaces" do
      expect( @ci.validate( 'lo' ) ).to eq false
      expect( @ci.validate( '' ) ).to eq false
      # assuming no one has a "nerbaderp" interface...
      expect( @ci.validate( 'nerbaderp' ) ).to eq false
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end
