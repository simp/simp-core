require 'simp/cli/config/item/ldap_sync_dn'
require 'rspec/its'
require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::LdapSyncDn do
  before :each do
    @ci = Simp::Cli::Config::Item::LdapSyncDn.new
  end

  describe "#validate" do
    it "validates ldap_sync_dns" do
      expect( @ci.validate 'cn=LDAPSync,ou=Hosts,dc=tasty,dc=bacon' ).to eq true
    end

    it "doesn't validate bad ldap_sync_dns" do
      expect( @ci.validate nil ).to eq false
      expect( @ci.validate false ).to eq false
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end
