require 'spec_helper_integration'

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

      %w[ puppet ipa agent-el6 agent-el7 ].each do |host|
        expect(records).to include(host)
      end
    end

    it 'should add a test user and a posix group' do
      next_year = Time.new.year + 1
      user_add = [
        'echo -n password |',
        'ipa user-add testuser',
        '--first=Test',
        '--last=User',
        '--displayname="Test User"',
        "--email=testuser@#{domain}.com",
        '--password',
        "--setattr=KrbPasswordExpiration=#{next_year}0606060606Z"
      ].join(' ')
      run_ipa_cmd(ipa_server, admin_password, user_add)
      run_ipa_cmd(ipa_server, admin_password, 'ipa group-add posixusers --desc "A POSIX group is required to log in with the user"')
      run_ipa_cmd(ipa_server, admin_password, 'ipa group-add-member posixusers --users=testuser')
    end

    it 'should install sshpass' do
      ipa_server.install_package('sshpass')
    end
    ipa_clients.each do |client|
      it "log into #{client}" do
        login = []
        login << 'sshpass -p password'
        login << 'ssh'
        login << '-o StrictHostKeyChecking=no'
        login << '-m hmac-sha1' if client.host_hash[:platform] =~ /el-6/
        login << '-l testuser'
        login << client.name
        login << 'uptime'

        result = on(ipa_server, login.join(' '))
        expect(result.stdout).to match(/load average:/)
      end
    end
  end
end
