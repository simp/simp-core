require 'spec_helper_integration'

def run_ipa_cmd(host, pass)
  on(ipa, "echo \"#{pass}\" | kinit admin")
  result = on(ipa, cmd)
  on(ipa, 'kdestroy')

  result
end

describe 'validate the ipa server' do

  ipa_server  = hosts_with_role(hosts, 'ipa_server').first
  ipa_clients = hosts_with_role(hosts, 'ipa_client')

  context 'server' do
    it 'should have 4 hosts in the inventory' do
      out   = run_ipa_cmd(ipa_server, 'ipa host-find')
      hosts = out.stdout.split("\n").grep(/Host name/)

      expect(hosts.length).to eq 4
    end

    it 'should have dns entries for each host' do
      out     = run_ipa_cmd(ipa_server, 'ipa dnsrecord-find test.case')
      records = out.stdout.split("\n").grep(/Record name/).map {|h|h.split(': ').last}

      expect(records).to include %w[ puppet ipa el6-client el7-client ]
    end

    it 'should add a test user and a posix group' do
      out = run_ipa_cmd(ipa_server, 'ipa user-add testuser --first=Test --last=User --displayname="Test User" --random')
      run_ipa_cmd(ipa_server, 'ipa group-add posixusers --desc "A POSIX group is required to log in with the user"')
      run_ipa_cmd(ipa_server, 'ipa group-add-member posixusers --users=testuser')

      $pass = out.stdout.split("\n").grep(/Random password/).first.split(': ').last
      puts $pass
    end

    ipa_clients.each do |client|
      it "log into #{client}"  do
        on(ipa_server, "ssh -o StrictHostKeyChecking=no -l testuser #{client} ls -l")
      end
      # test logins with testuser
    end
  end
end
