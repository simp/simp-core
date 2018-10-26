require 'spec_helper_tar'

test_name 'local user access'

# There have been SIMP problems in the past in which a local user with
# root privileges has not been able to login when that user's password
# has been changed.  This test is to make sure that regression never
# occurs!

describe 'local user access' do

  let(:files_dir) { 'spec/acceptance/common_files' }

  context 'local user login' do
    it 'should have localadmin user on all hosts' do
      # The user in this test, localadmin, has been ASSUMED to have
      # been setup in a previous test using the local_users.pp manifest.
      # Just in case someone rearranges the test files and doesn't
      # adjust this test, accordingly...
      on(hosts, 'id -u localadmin')
    end

    it 'local user should be able to login via ssh' do
      # This expect script ssh's to a host as a user and then runs 'date'.
      remote_script = install_expect_script(master, "#{files_dir}/ssh_cmd_script")
      hosts.each do |host|
        base_cmd ="#{remote_script} localadmin #{host.name} #{test_password(0)} date"

        # FIXME: Workaround for SIMP-5082
        cmd = adjust_ssh_ciphers_for_expect_script(base_cmd, master, host)
        on(master, cmd)
      end
    end

    it 'user should be able to change password' do
      # This expect script ssh's to a host as a user and changes the user's password
      # after login
      remote_script = install_expect_script(master, "#{files_dir}/ssh_change_password_script")

      # Allow user to change the password early
      on(hosts, 'passwd --minimum 0 localadmin')

      hosts.each do |host|
        base_cmd ="#{remote_script} localadmin #{host.name} #{test_password(0)} #{test_password(1)}"

        # FIXME: Workaround for SIMP-5082
        cmd = adjust_ssh_ciphers_for_expect_script(base_cmd, master, host)
        on(master, cmd)
      end
    end

    it 'local user should be able to login with new password via ssh' do
      hosts.each do |host|
        base_cmd ="#{EXPECT_SCRIPT_DIR}/ssh_cmd_script localadmin #{host.name} #{test_password(1)} date"

        # FIXME: Workaround for SIMP-5082
        cmd = adjust_ssh_ciphers_for_expect_script(base_cmd, master, host)
        on(master, cmd)
      end
    end
  end
end
