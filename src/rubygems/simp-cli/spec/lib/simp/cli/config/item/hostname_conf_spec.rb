require 'simp/cli/config/item/hostname_conf'

require 'simp/cli/config/item/network_interface'
require 'simp/cli/config/item/dns_search'
require 'simp/cli/config/item/dns_servers'
require 'simp/cli/config/item/gateway'
require 'simp/cli/config/item/hostname'
require 'simp/cli/config/item/ipaddress'
require 'simp/cli/config/item/netmask'
require 'simp/cli/config/item/network_dhcp'

require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::HostnameConf do
  before :each do
    @ci = Simp::Cli::Config::Item::HostnameConf.new
  end

  # TODO: how to test this?
  describe "#apply" do
    it "will do everything right" do
      skip "FIXME: how shall we test HostnameConf#apply()?"
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
end
