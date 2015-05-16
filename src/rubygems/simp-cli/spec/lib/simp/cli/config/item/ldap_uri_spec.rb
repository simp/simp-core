require 'simp/cli/config/item/ldap_uri'
require 'rspec/its'
require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::LdapUri do
  before :each do
    @ci = Simp::Cli::Config::Item::LdapUri.new
  end

  describe "#validate" do
    it "validates array with good hosts" do
      expect( @ci.validate ['ldap://log'] ).to eq true
      expect( @ci.validate ['ldap://log-server'] ).to eq true
      expect( @ci.validate ['ldap://log.loggitylog.org'] ).to eq true
      expect( @ci.validate ['ldap://192.168.1.1'] ).to eq true
      expect( @ci.validate ['ldap://192.168.1.1', 'ldap://log.loggitylog.org'] ).to eq true
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

