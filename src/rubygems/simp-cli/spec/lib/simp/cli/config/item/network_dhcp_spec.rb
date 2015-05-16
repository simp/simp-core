require 'simp/cli/config/item/network_dhcp'
require 'rspec/its'
require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::DHCP do
  before :each do
    @ci = Simp::Cli::Config::Item::DHCP.new
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end
