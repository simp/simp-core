require 'simp/cli/config/item/ipaddress'
require 'simp/cli/config/item/network_interface'
require 'rspec/its'
require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::IPAddress do
  before :each do
    @ci = Simp::Cli::Config::Item::IPAddress.new
  end

  describe "#os_value" do
    it "returns the ip address of the SIMP NIC" do
      env_var = "SIMP_NIC"
      if nic_value = ENV.fetch( env_var, false)
        nic = Simp::Cli::Config::Item::NetworkInterface.new
        nic.value =  nic_value
        @ci.config_items = { nic.key => nic }
        expect( @ci.os_value ).to be_a_kind_of(String)
      else
        skip %Q{to enable this test, set env var "$#{env_var}" to a configured interface}
      end
    end
  end


  describe "#validate" do
    it "validates IPv4 IPs" do
      expect( @ci.validate '192.168.1.1' ).to eq true
    end

    it "doesn't validate bad IPs" do
      expect( @ci.validate 'x.x.x.x' ).to eq false
      expect( @ci.validate '999.999.999.999' ).to eq false
      expect( @ci.validate '192.168.1.1/24' ).to eq false
      expect( @ci.validate nil ).to eq false
      expect( @ci.validate false ).to eq false
    end
  end
  it_behaves_like "a child of Simp::Cli::Config::Item"
end
