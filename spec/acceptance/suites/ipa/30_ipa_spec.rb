require 'spec_helper_integration'

describe 'IPA server integration' do

  ipa_server     = hosts_with_role(hosts, 'ipa_server').first
  ipa_clients    = hosts_with_role(hosts, 'ipa_client')

  domain     = fact_on(master, 'domain')
  ipa_domain = domain

  context 'hosts in the IPA domain' do
    it 'should have 3 hosts in the inventory' do
      out   = run_ipa_cmd(ipa_server, 'ipa host-find')
      hosts = out.stdout.split("\n").grep(/Host name/)

      expect(hosts.length).to eq 3
    end

    it 'should have DNS entries for each host' do
      out     = run_ipa_cmd(ipa_server, "ipa dnsrecord-find #{ipa_domain}")
      records = out.stdout.split("\n").grep(/Record name/).map {|h|h.split(': ').last}

      %w[puppet ipa agent-el7].each do |host|
        expect(records).to include(host)
      end
    end
  end

  context 'users in the IPA domain' do
    let(:default_yaml_filename) {
      '/etc/puppetlabs/code/environments/production/data/default.yaml'
    }

    let(:user_pwd) { test_password(:user, 0) }

    it 'should add a user and group, and then add the user to the group' do
      next_year = Time.new.year + 1
      user_add = [
        "echo -n '#{user_pwd}' |",
        'ipa user-add testuser',
        '--first=Test',
        '--last=User',
        '--displayname="Test User"',
        "--email=testuser@#{domain}.com",
        '--password',
        "--setattr=KrbPasswordExpiration=#{next_year}0606060606Z"
      ].join(' ')
      run_ipa_cmd(ipa_server, user_add)

      # This command will create a group with a POSIX attribute by default.
      # Linux users must be in a POSIX group in order to login.
      run_ipa_cmd(ipa_server, 'ipa group-add posixusers --desc "A POSIX group"')

      run_ipa_cmd(ipa_server, 'ipa group-add-member posixusers --users=testuser')
    end

    it 'should configure default hiera to allow the new IPA group access' do
      # NOTE: sssd is automatically configured to use the IPA domain, when
      #       the host is discovered to be on the domain.  So, all we have
      #       to do is allow the IPA group remote access to the server!
      hiera = YAML.load(on(master, "cat #{default_yaml_filename}").stdout)
      default_yaml = hiera.merge( {
        'pam::access::users'           => {
          'defaults'   => {
            'origins'    => ['ALL'],
            'permission' => '+'
          },
          'vagrant'      => nil,
          '(posixusers)' => nil,
        },
      } ).to_yaml
      create_remote_file(master, default_yaml_filename, default_yaml)
    end

    it 'should apply the configuration' do
      block_on(agents, :run_in_parallel => false) do |agent|
        retry_on(agent, 'puppet agent -t',
          :desired_exit_codes => [0],
          :retry_interval     => 15,
          :max_retries        => 3,
          :verbose            => true.to_s # work around beaker bug
        )
      end
    end

    it 'should install sshpass on the IPA server' do
      ipa_server.install_package('sshpass')
    end

    ipa_clients.each do |client|
      it "should ssh into #{client} from #{ipa_server} using IPA-created user" do
        login = []
        login << "sshpass -p '#{user_pwd}'"
        login << 'ssh'
        login << '-o PubkeyAuthentication=no'
        login << '-o StrictHostKeyChecking=no'
        login << '-l testuser'
        login << client.name
        login << 'uptime'

        result = on(ipa_server, login.join(' '))
        expect(result.stdout).to match(/load average:/)
      end
    end
  end
end
