require 'simp/cli/config/item/ldap_master'
require 'rspec/its'
require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::LdapMaster do
  before :each do
    @ci = Simp::Cli::Config::Item::LdapMaster.new
  end

  describe "#validate" do
    it "validates good ldap uri" do
      expect( @ci.validate 'ldap://master' ).to eq true
      expect( @ci.validate 'ldap://master-server' ).to eq true
      expect( @ci.validate 'ldap://master.ldap.org' ).to eq true
      expect( @ci.validate 'ldap://master.ldap.org' ).to eq true
      expect( @ci.validate 'ldap://192.168.1.1' ).to eq true

    end

    it "doesn't validate bad ldap uri" do
      expect( @ci.validate nil   ).to eq false
      expect( @ci.validate '' ).to    eq false
      expect( @ci.validate '   ' ).to eq false
      expect( @ci.validate false ).to eq false
      expect( @ci.validate [nil] ).to eq false
      expect( @ci.validate 'master' ).to eq false
      expect( @ci.validate 'ldap://master-' ).to eq false
      expect( @ci.validate 'ldap://-master' ).to eq false
      expect( @ci.validate 'ldap://master.loggitylog.org.' ).to eq false
      expect( @ci.validate 'ldap://.master.loggitylog.org' ).to eq false

    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end

