require 'simp/cli/config/item/grub_password'
require_relative( 'spec_helper' )

describe Simp::Cli::Config::Item::GrubPassword do
  before :each do
    @ci = Simp::Cli::Config::Item::GrubPassword.new
    @ci.silent = true
  end

  describe "#encrypt" do
    # NOTE: not much we can test except the hashed string length and characteristics of the type of hash
    it "encrypts grub_passwords" do
      crypted_pw = @ci.encrypt( 'foo' )
      if Facter.value('lsbmajdistrelease') <= '6'
        expect( crypted_pw ).to match /^\$6\$/
        expect( 97..98 ).to cover( crypted_pw.length )
      else
        skip "TODO: define tests for EL7+ grub passwords"
      end
    end
  end

  it_behaves_like "a child of Simp::Cli::Config::Item"
end
