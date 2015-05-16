require 'simp/cli/config/item/log_servers'
require 'rspec/its'
require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::LogServers do
  before :each do
    @ci = Simp::Cli::Config::Item::LogServers.new
  end

  describe "#recommended_value" do
    it "recommends nil when gateway is unavailable" do
      expect( @ci.recommended_value ).to be_nil
    end
  end
  describe "#recommended_value" do
    it "recommends nil when gateway is unavailable" do
      expect( @ci.recommended_value ).to be_nil
    end
  end

  describe "#validate" do
    it "validates array with good hosts" do
      expect( @ci.validate ['log'] ).to eq true
      expect( @ci.validate ['log-server'] ).to eq true
      expect( @ci.validate ['log.loggitylog.org'] ).to eq true
      expect( @ci.validate ['192.168.1.1'] ).to eq true
      expect( @ci.validate ['192.168.1.1', 'log.loggitylog.org'] ).to eq true

      # log_servers is optional and can be empty
      expect( @ci.validate nil   ).to eq true
      expect( @ci.validate '' ).to    eq true
      expect( @ci.validate '   ' ).to eq true
    end

    it "doesn't validate array with bad hosts" do
      expect( @ci.validate 0     ).to eq false
      expect( @ci.validate false ).to eq false
      expect( @ci.validate [nil] ).to eq false
      expect( @ci.validate ['log-'] ).to eq false
      expect( @ci.validate ['-log'] ).to eq false
      expect( @ci.validate ['log.loggitylog.org.'] ).to eq false
      expect( @ci.validate ['.log.loggitylog.org'] ).to eq false

    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end

