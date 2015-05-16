require 'simp/cli/config/item'
require 'rspec/its'
require_relative 'spec_helper'

describe Simp::Cli::Config::Item do
  before :each do
    @ci = Simp::Cli::Config::Item.new
  end

  describe "#initialize" do
    it "has no value when initialized" do
      expect( @ci.value ).to eq nil
    end

    it "has nil values when initialized" do
      expect( @ci.os_value ).to be_nil
    end
  end

  describe "#print_summary" do
    it "raises a RuntimeError on nil @key" do
      @ci.key = nil
      expect{ @ci.print_summary }.to raise_error( RuntimeError )
    end

    it "raises a RuntimeError on empty @key" do
      @ci.key = ""
      expect{ @ci.print_summary }.to raise_error( RuntimeError )
    end
  end

end

describe Simp::Cli::Config::ListItem do
  before :each do
    @ci = Simp::Cli::Config::ListItem.new
  end

  context "when @allow_empty_list = true" do
    before :each do
      @ci.allow_empty_list = false
      @ci.value = []
    end

    describe "#validate" do
      it "doesn't validate an empty array" do
        expect( @ci.validate [] ).to eq false
      end
    end
  end
end

describe Simp::Cli::Config::ActionItem do
  before :each do
    @ci         = Simp::Cli::Config::ActionItem.new
    @ci.key     = "action::item"
#    @ci.silent = true
  end

  describe "#apply" do
    before :all do
      @user       ||= ENV.fetch('USER')
      ENV['USER']   = 'root'            # fake user as root
    end
    context "(when @skip_apply = true)" do
      before :each do; @ci.skip_apply = true ; end

      it "does blah" do
        skip 'TODO: how shall we test generic safe_apply?'
        @ci.safe_apply
      end
    end

    context "(when @skip_apply = false)" do
      before :each do; @ci.skip_apply = false ; end

      it "does blah" do
        skip 'TODO: how shall we test generic safe_apply?'
        @ci.safe_apply
      end
    end

    after :all do
      ENV['USER']=@user
    end
  end
end



describe Simp::Cli::Config::PasswordItem do
  before :each do
    @ci        = Simp::Cli::Config::PasswordItem.new
    @ci.silent = true
  end

  it "validates good passwords" do
    expect( @ci.validate( 'duP3rP@ssw0r!' ) ).to eq true
  end

  it "doesn't validate bad passwords" do
    expect( @ci.validate( 'short' ) ).to     eq false
    expect( @ci.validate( '' ) ).to          eq false
    expect( @ci.validate( '123456789' ) ).to eq false
  end
end
