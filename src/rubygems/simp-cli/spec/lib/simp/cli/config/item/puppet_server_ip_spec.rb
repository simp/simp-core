require 'simp/cli/config/item/puppet_server_ip'
require 'rspec/its'
require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::PuppetServerIP do
  before :each do
    @ci = Simp::Cli::Config::Item::PuppetServerIP.new
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
