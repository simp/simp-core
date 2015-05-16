require 'simp/cli/config/item/answers_yaml_file_writer'
require 'simp/cli/config/item/puppet_server'
require 'simp/cli/config/item/puppet_server_ip'
require 'rspec/its'
require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::AnswersYAMLFileWriter do
  before :all do
    @ci        = Simp::Cli::Config::Item::AnswersYAMLFileWriter.new
    @ci.silent = true   # turn off command line summary on stdout
    @tmp_dir   = File.expand_path( 'tmp', File.dirname( __FILE__ ) )
  end


  describe "#print_answers_yaml" do
    before :each do
      ci                = Simp::Cli::Config::Item.new
      ci.key            = 'item'
      ci.value          = 'foo'
      ci.description    = 'A simple item'
      list              = { foo: ci }

      ci                = Simp::Cli::Config::ListItem.new
      ci.key            = 'list'
      ci.value          = ['one','two','three']
      ci.description    = 'A simple list'
      list[ci.key]      = ci

      ci                = Simp::Cli::Config::YesNoItem.new
      ci.key            = 'yesno'
      ci.value          = true
      ci.description    = 'A simple yes/no item'
      list[ci.key]      = ci

      @simple_item_list = list
    end

    it "prints parseable yaml" do
      io = StringIO.new
      @ci.print_answers_yaml( io, @simple_item_list )
      y = YAML.load( io.string )

      expect( y ).to be_kind_of Hash
      expect( y ).not_to be_empty
      expect( y['item'] ).to  eq('foo')
      expect( y['list'] ).to  eq(['one','two','three'])
      expect( y['yesno'] ).to eq(true)
    end
  end


  context "when writing a yaml file" do
    before :context do
      item             = Simp::Cli::Config::Item::PuppetServerIP.new
      item.value       = '1.2.3.4'
      @ci.config_items[item.key] = item

      item             = Simp::Cli::Config::Item::PuppetServer.new
      item.value       = 'puppet.domain.tld'
      @ci.config_items[item.key] = item

      @tmp_file = File.expand_path( 'answers_yaml_file_writer.yaml', @tmp_dir )
      FileUtils.mkdir_p   @tmp_dir
      @ci.file = @tmp_file
      @ci.apply
    end

    it "writes a file" do
      expect( File.exists?( @tmp_file ) ).to be true
    end

    it "writes the correct values" do
      lines = File.readlines( @tmp_file ).join( "\n" )
      expect( lines ).to match(%r{^\W*puppet::server\W*:\W*puppet.domain.tld\b})
      expect( lines ).to match(%r{^\W*puppet::server::ip\W*:\W*1.2.3.4\b})
    end

    after :context do
      FileUtils.rm @tmp_file
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like "a child of Simp::Cli::Config::Item"
end

