require 'simp/cli/config/item/simp_yum_servers'
require 'rspec/its'
require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::SimpYumServers do
  before :each do
    @ci = Simp::Cli::Config::Item::SimpYumServers.new
  end

  describe "#validate" do
    it "validates array with good hosts" do
      expect( @ci.validate ['yum'] ).to eq true
      expect( @ci.validate ['yum-server'] ).to eq true
      expect( @ci.validate ['yum.yummityyum.org'] ).to eq true
      expect( @ci.validate ['192.168.1.1'] ).to eq true
      expect( @ci.validate ['192.168.1.1'] ).to eq true
      expect( @ci.validate ["%{hiera('puppet::server')}"] ).to eq true
      expect( @ci.validate ["%{::domain}"] ).to eq true

      # yum_servers is allowed to be empty
      expect( @ci.validate nil ).to eq true
      expect( @ci.validate '   ' ).to eq true
      expect( @ci.validate '' ).to eq true
      expect( @ci.validate [] ).to eq true
    end

    it "doesn't validate array with bad hosts" do
      expect( @ci.validate 0     ).to eq false
      expect( @ci.validate false ).to eq false
      expect( @ci.validate [nil] ).to eq false
      expect( @ci.validate ['yum-'] ).to eq false
      expect( @ci.validate ['-yum'] ).to eq false
      expect( @ci.validate ['yum.yummityyum.org.'] ).to eq false
      expect( @ci.validate ['.yum.yummityyum.org'] ).to eq false
      expect( @ci.validate ["%[hiera('puppet::server')]"] ).to eq false
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end

