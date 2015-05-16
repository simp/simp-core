require 'simp/cli/config/item/rsync_base'
require 'rspec/its'
require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::RsyncBase do
  before :each do
    @ci = Simp::Cli::Config::Item::RsyncBase.new
  end

  describe "#validate" do
    it "validates a good rsync base path" do
      expect( @ci.validate "/var/simp/rsync/%{::operatingsystem}/%{::lsbmajdistrelease}" ).to eq true
      expect( @ci.validate "/srv/simp/rsync/%{::operatingsystem}/%{::lsbmajdistrelease}" ).to eq true
    end

    it "doesn't validate bad rsync base paths" do
      expect( @ci.validate '..' ).to eq false
    end
  end

  describe "#recommended_value" do
    it "recommends a /srv or /var/simp path" do
      expect( @ci.recommended_value ).to match %r{^(/var/simp/rsync|/srv/simp/rsync|/srv/rsync)}
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end
