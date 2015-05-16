require 'simp/cli/config/item/ldap_sync_hash'
require 'rspec/its'
require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::LdapSyncHash do
  before :each do
    @ci = Simp::Cli::Config::Item::LdapSyncHash.new
  end

  describe "#encrypt" do
    it "encrypts a known password and salt to the correct SHA-1 password hash" do
      expect( @ci.encrypt( 'foo', "\xef\xb2\x2e\xac" ) ).to eq '{SSHA}zxOLQEdncCJTMObl5s+y1N/Ydh3vsi6s'
    end
  end

  describe "#validate" do
    it "validates OpenLDAP-format SHA-1 algorithm (FIPS 160-1) password hash" do
      expect( @ci.validate '{SSHA}Y6x92VpatHf9G6yMiktUYTrA/3SxUFm' ).to eq true
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end
