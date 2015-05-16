require 'simp/cli/config/item/puppet_autosign'
require 'rspec/its'
require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::PuppetAutosign do
  before :each do
    @ci = Simp::Cli::Config::Item::PuppetAutosign.new
  end

  describe "#validate" do
    it "validates array with good autosign entries" do
      expect( @ci.validate ['10.0.71.1'] ).to eq true
      expect( @ci.validate ['192.168.1.1', '8.8.8.8'] ).to eq true
      expect( @ci.validate ['10.0.71.1'] ).to eq true
    end

    it "doesn't validate array with bad autosign entries" do
      expect( @ci.validate 0     ).to eq false
      expect( @ci.validate nil   ).to eq false
      expect( @ci.validate false ).to eq false
      expect( @ci.validate [nil] ).to eq false
      expect( @ci.validate ['1.2.3'] ).to eq false
      expect( @ci.validate ['1.2.3.999'] ).to eq false
      expect( @ci.validate ['8.8.8.8.'] ).to eq false
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end

