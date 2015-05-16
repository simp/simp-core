shared_examples 'a child of Simp::Cli::Config::Item' do
  describe '#to_yaml_s' do
    it 'does not contain FIXME' do
      expect( @ci.to_yaml_s ).not_to match(/FIXME/)
    end
  end
end


shared_examples "an Item that doesn't output YAML" do
  describe "#to_yaml_s" do
    it "is empty" do
      expect( @ci.to_yaml_s.to_s ).to be_empty
    end
  end
end
