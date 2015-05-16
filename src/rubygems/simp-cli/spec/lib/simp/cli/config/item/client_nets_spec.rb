require 'simp/cli/config/item/client_nets'

require 'simp/cli/config/item/ipaddress'
require 'simp/cli/config/item/netmask'
require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::ClientNets do
  before :each do
    @ci = Simp::Cli::Config::Item::ClientNets.new
    @ci.silent = true
  end


  describe "#recommended_value" do
    it "recommends no CIDR notation when IP + netmask are unavailable" do
      expect( @ci.recommended_value ).to be_nil
    end

    it "recommends correct CIDR notation for a given IP + netmask" do
      @ci.config_items = create_prior_items( '10.10.6.227', '255.255.255.0' )
      expect( @ci.recommended_value ).to eq ['10.10.6.0/24']

      @ci.config_items = create_prior_items( '10.10.10.99', '255.255.255.224' )
      expect( @ci.recommended_value ).to eq ['10.10.10.96/27']
    end
  end


  describe "#validate" do
    it "validates array of good cidr nets" do
      expect( @ci.validate ['10.0.71.0/24'] ).to eq true
      expect( @ci.validate ['1.2.3.0/24'] ).to eq true
      expect( @ci.validate ['10.10.10.0/16', '192.168.1.0/23'] ).to eq true
      # crazy, but valid CIDR (equiv to 33,554,432 class C networks!)
      expect( @ci.validate ['1.2.3.0/0'] ).to eq true
    end

    it "doesn't validate array with bad cidr nets" do
      expect( @ci.validate 0     ).to eq false
      expect( @ci.validate nil   ).to eq false
      expect( @ci.validate false ).to eq false
      expect( @ci.validate [nil] ).to eq false
      expect( @ci.validate ['1.2.3.999/24'] ).to eq false
      expect( @ci.validate ['1.2.3.999/24/24'] ).to eq false
      expect( @ci.validate ['1.2.3.999/z'] ).to eq false
      expect( @ci.validate ['1.2.3.0/24', '192.168.1.0/99'] ).to eq false
    end

    it "doesn't validate an empty array" do
      expect( @ci.validate [] ).to eq false
    end
  end

  def create_prior_items ip, netmask
    items = {}
    _ip = Simp::Cli::Config::Item::IPAddress.new
    _ip.value = ip
    items[ _ip.key ] = _ip
    _netmask = Simp::Cli::Config::Item::Netmask.new
    _netmask.value = netmask
    items[ _netmask.key ] = _netmask
    items
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end
