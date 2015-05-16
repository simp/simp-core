require 'simp/cli/config/item/rsync_timeout'
require 'rspec/its'
require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::RsyncTimeout do
  before :each do
    @ci = Simp::Cli::Config::Item::RsyncTimeout.new
  end

  describe "#validate" do
    it "validates a good rsync timeout" do
      expect( @ci.validate "1" ).to eq true
    end

    it "doesn't validate a bad rsync timeout" do
      expect( @ci.validate '-1' ).to eq false
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end
