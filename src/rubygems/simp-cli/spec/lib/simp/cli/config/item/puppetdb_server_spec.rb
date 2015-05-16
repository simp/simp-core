require 'simp/cli/config/item/puppetdb_server'
require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::PuppetDBServer do
  before :each do
    @ci = Simp::Cli::Config::Item::PuppetDBServer.new
    @ci.silent = true
  end

  describe "#validate" do
    it "validates puppet fqdn" do
      expect( @ci.validate 'puppet.change.me' ).to eq true
    end

    it "validates hiera" do
      expect( @ci.validate "%{hiera('puppet::server')}" ).to eq true
    end

    it "doesn't validate empty string" do
      expect( @ci.validate '' ).to eq false
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end
