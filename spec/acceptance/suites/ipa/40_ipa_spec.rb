# require 'spec_helper_integration'

def run_ipa_cmd(host, pass, cmd)
  on(host, "echo \"#{pass}\" | kinit admin")
  result = on(host, cmd)
  on(host, 'kdestroy')

  result
end

describe 'validate the ipa server' do

  admin_password = '@dm1n=P@ssw0r'
  ipa_server     = hosts_with_role(hosts, 'ipa_server').first
  ipa_clients    = hosts_with_role(hosts, 'ipa_client')

  domain     = fact_on(master, 'domain')
  ipa_domain = domain

  context 'server' do
    it 'should have 4 hosts in the inventory' do
      out   = run_ipa_cmd(ipa_server, admin_password, 'ipa host-find')
      hosts = out.stdout.split("\n").grep(/Host name/)

      expect(hosts.length).to eq 4
    end

    it 'should have dns entries for each host' do
      out     = run_ipa_cmd(ipa_server, admin_password, "ipa dnsrecord-find #{ipa_domain}")
      records = out.stdout.split("\n").grep(/Record name/).map {|h|h.split(': ').last}

      expect(records).to include %w[ puppet ipa el6-client el7-client ]
    end

    it 'should add a test user and a posix group' do
      out = run_ipa_cmd(ipa_server, admin_password, 'ipa user-add testuser --first=Test --last=User --displayname="Test User" --random')
      run_ipa_cmd(ipa_server, admin_password, 'ipa group-add posixusers --desc "A POSIX group is required to log in with the user"')
      run_ipa_cmd(ipa_server, admin_password, 'ipa group-add-member posixusers --users=testuser')

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
