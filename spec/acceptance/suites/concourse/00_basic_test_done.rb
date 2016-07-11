require 'spec_helper_acceptance'

test_name 'concourse'

describe 'concourse' do

  context 'setup' do
    hosts.each do |host|
      it "should set up concourse on #{host}"
    end
  end
end
