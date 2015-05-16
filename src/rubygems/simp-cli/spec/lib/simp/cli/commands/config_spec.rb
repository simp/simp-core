require 'simp/cli/commands/config'
require 'simp/cli/config/item'
require_relative( '../spec_helper' )

require 'yaml'

describe Simp::Cli::Commands::Config do
###  describe ".print_answers_yaml" do
###    before :each do
###      ci                = Simp::Cli::Config::Item.new
###      ci.key            = 'item'
###      ci.value          = 'foo'
###      ci.description    = 'A simple item'
###      list              = { foo: ci }
###
###      ci                = Simp::Cli::Config::ListItem.new
###      ci.key            = 'list'
###      ci.value          = ['one','two','three']
###      ci.description    = 'A simple list'
###      list[ci.key]      = ci
###
###      ci                = Simp::Cli::Config::YesNoItem.new
###      ci.key            = 'yesno'
###      ci.value          = true
###      ci.description    = 'A simple yes/no item'
###      list[ci.key]      = ci
###
###      @simple_item_list = list
###    end
###
###    it "prints yaml" do
###      io = StringIO.new
###      Simp::Cli::Commands::Config.print_answers_yaml io, @simple_item_list
###      y = YAML.load io.string
###      expect( y ).to be_kind_of Hash
###      expect( y ).not_to be_empty
###      expect( y['item'] ).to  eq('foo')
###      expect( y['list'] ).to  eq(['one','two','three'])
###      expect( y['yesno'] ).to eq(true)
###    end
###  end
end
