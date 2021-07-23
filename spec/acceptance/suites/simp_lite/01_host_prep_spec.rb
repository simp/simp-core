require 'spec_helper_integration'

test_name 'Host prep for simp-lite scenario'

describe 'Host prep for simp-lite scenario' do

  # In order to verify the firewall is appropriately running and enabled for
  # the SIMP server but not for the clients, need to start with it stopped
  # and disabled on all hosts.
  context 'ensure firewall disabled' do
    hosts.each do |host|
      it 'iptables should not be running' do
        on(host, 'puppet resource service iptables ensure=stopped enable=false')
      end

      it 'firewalld should not be running' do
        on(host, 'puppet resource service firewalld ensure=stopped enable=false')
      end
    end
  end
end
