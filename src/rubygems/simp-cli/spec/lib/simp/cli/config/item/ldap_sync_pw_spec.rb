require 'simp/cli/config/item/ldap_sync_pw'
require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::LdapSyncPw do
  before :each do
    @ci = Simp::Cli::Config::Item::LdapSyncPw.new
    @ci.silent = true
  end

  describe "#validate" do
    it "validates common_runlevel_defaults" do
      expect( @ci.validate 'a!S@d3F$g5H^j&k' ).to eq true
    end

    it "doesn't validate empty passwords" do
      expect( @ci.validate '' ).to eq false
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end
