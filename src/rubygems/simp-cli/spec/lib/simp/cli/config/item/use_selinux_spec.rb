require 'simp/cli/config/item/use_selinux'
require 'rspec/its'
require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::UseSELinux do
  before :each do
    @ci = Simp::Cli::Config::Item::UseSELinux.new
  end

  describe "#validate" do
    it "validates valid values" do
      expect( @ci.validate 'enforcing' ).to eq true
      expect( @ci.validate 'permissive' ).to eq true
      expect( @ci.validate 'disabled' ).to eq true
    end

    it "doesn't validate other things" do
      expect( @ci.validate 'ydd' ).to  eq false
      expect( @ci.validate nil ).to eq false
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end
