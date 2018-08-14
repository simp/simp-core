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
      # This test will use an expect script that ssh's to a host as a
      # user and then runs 'date'.
      scp_to(master, "#{files_dir}/ssh_cmd_script", '/usr/local/bin/ssh_cmd_script')
      on(master, "chmod +x /usr/local/bin/ssh_cmd_script")
      master_os_major = fact_on(master, 'operatingsystemmajrelease')
      hosts.each do |host|
        cmd ="/usr/local/bin/ssh_cmd_script localadmin #{host.name} #{test_password(0)} date"

        # FIXME: Workaround for SIMP-5082
        os_major = fact_on(host, 'operatingsystemmajrelease')
        if master_os_major.to_s == '7'
          cmd +=" '-o MACs=hmac-sha1'" if (os_major.to_s == '6')
        elsif master_os_major.to_s == '6'
          cmd +=" '-o MACs=hmac-sha2-256'" if (os_major.to_s == '7')
        end

        on(master, cmd)
      end
    end

    it 'user should be able to change password' do
begin
      scp_to(master, "#{files_dir}/ssh_change_password_script", '/usr/local/bin/ssh_change_password_script')
      on(master, "chmod +x /usr/local/bin/ssh_change_password_script")

      # Allow user to change the password early
      on(hosts, 'passwd --minimum 0 localadmin')

      master_os_major = fact_on(master, 'operatingsystemmajrelease')
      hosts.each do |host|
        cmd ="/usr/local/bin/ssh_change_password_script localadmin #{host.name} #{test_password(0)} #{test_password(1)}"

        # FIXME: Workaround for SIMP-5082
        os_major = fact_on(host, 'operatingsystemmajrelease')
        if master_os_major.to_s == '7'
          cmd +=" '-o MACs=hmac-sha1'" if (os_major.to_s == '6')
        elsif master_os_major.to_s == '6'
          cmd +=" '-o MACs=hmac-sha2-256'" if (os_major.to_s == '7')
        end

        on(master, cmd)
      end
rescue => e
puts "#{e}"
require 'pry-byebug'
binding.pry
end
    end

    it 'local user should be able to login with new password via ssh' do
begin
      master_os_major = fact_on(master, 'operatingsystemmajrelease')
      hosts.each do |host|
        cmd ="/usr/local/bin/ssh_cmd_script localadmin #{host.name} #{test_password(1)} date"

        # FIXME: Workaround for SIMP-5082
        os_major = fact_on(host, 'operatingsystemmajrelease')
        if master_os_major.to_s == '7'
          cmd +=" '-o MACs=hmac-sha1'" if (os_major.to_s == '6')
        elsif master_os_major.to_s == '6'
          cmd +=" '-o MACs=hmac-sha2-256'" if (os_major.to_s == '7')
        end

        on(master, cmd)
      end
rescue => e
puts "#{e}"
require 'pry-byebug'
binding.pry
end

    end
  end
end
