require 'spec_helper_integration'
require 'inspec'
require 'json'

test_name 'compliance check'

describe 'use inspec to check compliance' do
  # masters     = hosts_with_role(hosts, 'master')
  # agents      = hosts_with_role(hosts, 'agent')
  # master_fqdn = fact_on(master, 'fqdn')

  hosts.each do |host|
    context 'pause' do
      it 'pls stop' do
        require 'pry';binding.pry
      end
    end

    context 'RHEL STIG' do
      # docs http://inspec.io/docs/reference/cli/#exec
      profile_dir = '/tmp/inspec-stig-rhel7'
      timestamp = Time.now.to_i
      it 'should install inspec' do
        host.install_package('https://packages.chef.io/files/stable/inspec/1.21.0/el/7/inspec-1.21.0-1.el7.x86_64.rpm')
      end
      it 'should copy over the profile' do
        scp_to(host, 'spec/fixtures/inspec-stig-rhel7', profile_dir)
      end
      it 'run inspec and export results' do
        json_output  = on(host, "inspec exec --format json #{profile_dir}", :silent => true )
        File.open("inspec_json-#{timestamp}.log", 'w') { |file| file.write(json_output.stdout) }

        # doc_output  = on(host, "inspec exec --format documentation #{profile_dir}", :silent => true )
        # File.open("inspec_doc-#{timestamp}.log", 'w') { |file| file.write(doc_output.stdout) }

        # junit_output = on(host, "inspec exec --format junit #{profile_dir}")
      end
    end


    # context 'RHEL STIG local inspec, remote test' do
    #   it 'it should be compliant' do
    #
    #     Inspec::Log.init(STDERR)
    #     # Inspec::Log.level = :debug
    #
    #     ssh_conf = File.read(master.host_hash[:ssh][:config])
    #     port = ssh_conf.split("\n").grep(/Port/)[0].split[1]
    #     key = ssh_conf.split("\n").grep(/IdentityFile/)[0].split[1]
    #
    #     # inspec exec https://github.com/inspec-stigs/inspec-stig-rhel7
    #     #   -t ssh://root@10.255.77.133
    #     #   -i /home/nick/.vagrant.d/insecure_private_key
    #
    #     runner_options = {
    #       'profiles_path' => 'spec/fixtures/inspec-stig-rhel7',
    #       'format'        => 'junit',
    #       'backend'       => 'ssh',
    #       'host'          => 'localhost',
    #       'port'          => port,
    #       'user'          => master.host_hash[:ssh][:user],
    #       'keys_only'     => true,
    #       'key_files'     => key
    #     }
    #     checker = Inspec::Runner.new(runner_options)
    #     # checker.add_target('https://github.com/inspec-stigs/inspec-stig-rhel7')
    #     checker.add_target('spec/fixtures/inspec-stig-rhel7')
    #
    #     require 'pry';binding.pry
    #     result = checker.run
    #
    #     require 'pry';binding.pry
    #     # expect(result).not_to eq object
    #
    #   end
    # end

  end

end
