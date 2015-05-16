require 'simp/cli/config/item/ntp_servers'
require 'rspec/its'
require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::NTPServers do
  before :each do
    @ci = Simp::Cli::Config::Item::NTPServers.new
  end

#  describe "#recommended_value" do
#  TODO: how to test this when os_value returns a valid value?
#    it "recommends nil when gateway is unavailable" do
#      expect( @ci.recommended_value ).to be_nil
#    end
#  end

  describe "#validate" do
    it "validates array with good hosts" do
      expect( @ci.validate ['pool.ntp.org'] ).to eq true
      expect( @ci.validate ['192.168.1.1'] ).to eq true
      expect( @ci.validate ['192.168.1.1', 'pool.ntp.org'] ).to eq true
      # NTP servers are optional, so nil is okay
      expect( @ci.validate nil   ).to eq true
    end

    it "doesn't validate array with bad hosts" do
      expect( @ci.validate 0     ).to eq false
      expect( @ci.validate false ).to eq false
      expect( @ci.validate [nil] ).to eq false
      expect( @ci.validate ['pool.ntp.org.'] ).to eq false
      expect( @ci.validate ['192.168.1.1.'] ).to eq false
      expect( @ci.validate ['1.2.3.4/24'] ).to eq false
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end
