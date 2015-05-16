require 'simp/cli/config/item/network_conf'

require 'simp/cli/config/item/network_interface'
require 'simp/cli/config/item/dns_search'
require 'simp/cli/config/item/dns_servers'
require 'simp/cli/config/item/gateway'
require 'simp/cli/config/item/hostname'
require 'simp/cli/config/item/ipaddress'
require 'simp/cli/config/item/netmask'
require 'simp/cli/config/item/network_dhcp'

require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::NetworkConf do
  before :each do
    @ci = Simp::Cli::Config::Item::NetworkConf.new
  end


  # TODO: how to test this?
  describe "#apply" do
    it "will puppet apply a static network interface" do
      @ci.config_items = init_config_items( {'dhcp' => 'static'} )
      skip "FIXME: how shall we test NetworkConf#apply()?"
      @ci.apply
    end

    it "will puppet apply a dhcp network interface" do
      @ci.config_items = init_config_items( {'dhcp' => 'dhcp'} )
      skip "FIXME: how shall we test NetworkConf#apply()?"
      @ci.apply
    end
  end


  # helper method to create a number of previous answers
  def init_config_items( extra_answers={} )
    answers = {}
    things  = {
      'NetworkInterface' => 'br1',
      'DHCP'             => 'static',
      'Hostname'         => 'scli.tasty.bacon',
      'IPAddress'        => '10.0.71.50',
      'Netmask'          => '255.255.255.0',
      'Gateway'          => '10.0.71.1',
      'DNSServers'       => ['10.0.71.7', '8.8.8.8'],
      'DNSSearch'        => 'tasty.bacon',
    }
    things.each do |name,value|
      item = Simp::Cli::Config::Item.const_get(name).new
      if extra_answers.keys.include? item.key
        item.value = extra_answers.fetch( item.key )
      else
        item.value = value
      end
      answers[ item.key ] = item
    end
    answers
  end

  it_behaves_like "an Item that doesn't output YAML"
  #it_behaves_like "a child of Simp::Cli::Config::Item"
end
