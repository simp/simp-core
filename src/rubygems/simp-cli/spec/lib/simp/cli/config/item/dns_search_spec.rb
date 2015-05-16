require 'simp/cli/config/item/dns_search'
require 'simp/cli/config/item/hostname'
require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::DNSSearch do
  before :all do
    @files_dir = File.expand_path( 'files', File.dirname( __FILE__ ) )
  end

  before :each do
    @ci = Simp::Cli::Config::Item::DNSSearch.new
  end


  describe '#recommended_value' do
    context 'when /etc/resolv.conf is populated' do
      it 'handles a single domain' do
        @ci.file = File.join(@files_dir,'resolv.conf__single')
        expect( @ci.recommended_value).to eq ['tasty.bacon']
      end

      it 'handles multiple domains' do
        @ci.file = File.join(@files_dir,'resolv.conf__multiple')
        expect( @ci.recommended_value).to eq ['tasty.bacon', 'yucky.bacon', 'instant.bacon']
      end
    end

    context 'when /etc/resolv.conf is empty' do
      before :each do
        @ci.file = '/dev/null'
      end

      it 'recommends ipaddress (when available)' do
        fqdn = Simp::Cli::Config::Item::Hostname.new
        fqdn.value = 'puppet.snazzy.domain'
        @ci.config_items[ fqdn.key ] = fqdn

        expect( @ci.recommended_value.size ).to eq 1
        expect( @ci.recommended_value      ).to eq ['snazzy.domain']
      end

      it 'recommends a must-change value (when ipaddress is not available)' do
        expect( @ci.recommended_value.size  ).to eq 1
        expect( @ci.recommended_value.first ).to match( /change/ )
      end
    end
  end


  describe "#validate" do
    it "validates array with domains" do
      expect( @ci.validate ['simp.dev', 'google.com', '0simp.dev'] ).to eq true
    end

    it "doesn't validate array with bad domains" do
      expect( @ci.validate [nil]         ).to eq false
      expect( @ci.validate ['simp.dev.'] ).to eq false
      expect( @ci.validate ['.simp.dev'] ).to eq false
    end

    it "doesn't validate empty array" do
      expect( @ci.validate []         ).to eq false
    end

    it "doesn't validate nonsense" do
      expect( @ci.validate 0             ).to eq false
      expect( @ci.validate nil           ).to eq false
      expect( @ci.validate false         ).to eq false
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end

