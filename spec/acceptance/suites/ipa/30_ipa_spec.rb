require 'spec_helper_integration'

describe 'ip and puppet together finally' do
  clients   = hosts_with_role(hosts, 'ipa-client')
  ipaserver = hosts_with_role(hosts, 'ipa-server')

  ipaserver.each do |server|
    context 'server' do
      it 'should have 4 hosts in the inventory' do
        on(server, 'echo "@dm1n=P@ssw0r" | kinit admin')
        out = on(server, 'ipa host-find')
        on(server, 'kdestroy')
        num_hosts = out.stdout.split("\n").grep(/Host name/).length

        expect(num_hosts).to eq 4
      end

      it 'should have dns entries for each host' do
        on(server, 'echo "@dm1n=P@ssw0r" | kinit admin')
        out = on(server, 'ipa dnsrecord-find test.case')
        on(server, 'kdestroy')
        require 'pry';binding.pry
        records = out.stdout.split("\n").grep(/Record name/).map {|h|h.split(': ').last}

        expect(records).to include %w[ puppet ipa el6-client el7-client ]
      end

      it 'should add a test user and a posix group' do
        on(server, 'echo "@dm1n=P@ssw0r" | kinit admin')
        on(server, 'ipa group-add posixusers --desc "A POSIX group is required to log in with the user"')
        out = on(server, 'ipa user-add testuser --first=Test --last=User --displayname="Test User" --random')
        on(server, 'ipa group-add-member posixusers --users=testuser')
        on(server, 'kdestroy')
        $pass = out.stdout.split("\n").grep(/Random password/).first.split(': ').last
        puts $pass
      end

      clients.each do |client|
        it "log into #{client}"  do
          require 'pry';binding.pry
          on(server, "ssh -o StrictHostKeyChecking=no -l testuser #{client} ls -l")
        end
        # test logins with testuser
      end
    end
  end
end
