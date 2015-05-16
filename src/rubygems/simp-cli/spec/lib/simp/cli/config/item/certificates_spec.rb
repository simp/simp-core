require 'simp/cli/config/item/certificates'
require 'simp/cli/config/item/hostname'
require 'rspec/its'
require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::Certificates do
  before :each do
    @ci        = Simp::Cli::Config::Item::Certificates.new
    @ci.silent = true
    @hostname  = 'puppet.testing.fqdn'
    item       = Simp::Cli::Config::Item::Hostname.new
    item.value = @hostname
    @ci.config_items[ item.key ] = item

    @files_dir = File.expand_path( 'files', File.dirname( __FILE__ ) )
  end


  describe "#apply" do
    context 'using external files,' do
      before :each do
        @tmp_dir  = Dir.mktmpdir( File.basename(__FILE__),
                                  File.expand_path('tmp', File.dirname( __FILE__ )) )
        @tmp_dirs = {
                      :keydist => File.join( @tmp_dir, 'keydist'),
                      :fake_ca => File.join( @tmp_dir, 'FakeCA'),
                    }
        FileUtils.mkdir @tmp_dirs.values
        src_dir   = File.join(@files_dir,'FakeCA')
        FileUtils.cp_r( Dir["#{src_dir}/*"], @tmp_dirs[:fake_ca] )

        @ci.dirs   = @tmp_dirs
        @ci.apply
      end

      it 'runs gencerts_nopass.sh auto' do
        dir = File.join( @tmp_dirs[:keydist], @hostname )
        expect( File.exists? dir ).to be true
      end

      after :each do
        FileUtils.remove_entry_secure @tmp_dir
      end
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end

