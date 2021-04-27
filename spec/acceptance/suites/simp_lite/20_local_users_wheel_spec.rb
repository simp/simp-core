require 'spec_helper_integration'

test_name 'Wheel configuration test'
#
# Make sure that pam::wheel was not included on the  agents but
# was set up on the puppet server

puppetserver   = only_host_with_role(hosts, 'master')

describe 'Wheel configuration test' do

  let(:files_dir) { 'spec/acceptance/common_files' }

  context 'check pam::wheel is not installed on clients but is on server' do

    it 'should have localadmin user on all hosts' do
      # The user in this test, localadmin, has been ASSUMED to have
      # been setup in a previous test using the local_users.pp manifest.
      # Just in case someone rearranges the test files and doesn't
      # adjust this test, accordingly...
      on(hosts, 'id -u localadmin')
    end

    hosts.each do |host|
      it 'should su on clients but not on puppetserver' do
        # Looks like some of the vagrant boxes (el8 mostly) have added
        # restrictions to pam.d/su to not allow anyone to su to root
        # using pam_succeed_if user notin root:vagrant
        # This will remove that line from /etc/pam.d/su if it exists.
        on(host,'sed -i  \'/^account\s*required\s*pam_succeed_if.so user notin .*$/d\' /etc/pam.d/su')
        remote_script = install_expect_script(host, "#{files_dir}/su_root_wheel_check_script")
        result = on(host,"#{remote_script} localadmin #{host.name} #{test_password(0)}",:accept_all_exit_codes => true)
        if host == puppetserver
          expect(result.stdout).to include('su: Permission denied')
        else
          expect(result.stdout).to include('su to root for localadmin succeeded')
        end
      end
    end

  end

end
