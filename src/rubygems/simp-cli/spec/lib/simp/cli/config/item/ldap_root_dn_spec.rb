require 'simp/cli/config/item/ldap_root_dn'
require 'rspec/its'
require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::LdapRootDn do
  before :each do
    @ci = Simp::Cli::Config::Item::LdapRootDn.new
  end

  describe "#validate" do
    it "validates ldap_root_dns" do
      expect( @ci.validate 'cn=hostAuth,ou=Hosts,dc=tasty,dc=bacon' ).to eq true
    end

    it "doesn't validate bad ldap_root_dns" do
      expect( @ci.validate 'dc=tasty,dc=bacon' ).to eq false
      expect( @ci.validate nil ).to eq false
      expect( @ci.validate false ).to eq false
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end
