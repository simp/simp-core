require 'spec_helper_integration'

describe 'ip and puppet together finally' do
  clients   = hosts_with_role(hosts, 'ipa-client')
  ipaserver = hosts_with_role(hosts, 'ipa-server')

  ipaserver.each do |server|
    context 'server' do
      # test ipa host inventory
      # kinit admin; ipa host-find

      it 'should add a test user' do
        # kinit admin; ipa user-add testuser
        out = on(server, 'ipa user-add testuser --first=Test --last=User --displayname="Test User" --random')
        $pass = out.stdout.split("\n").grep(/Random password/).first.split(': ').last
        puts $pass
      end
    end
  end

  clients.each do |client|
    context 'clients' do
      it 'should pry' do
        require 'pry';binding.pry
      end
      # test logins with testuser
    end
  end
end
