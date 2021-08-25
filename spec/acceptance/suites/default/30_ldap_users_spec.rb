require 'spec_helper_integration'

test_name 'LDAP user access'

# This test verifies LDAP user access scenarios
#
# - All LDAP users are known to all hosts.
# - LDAP users granted ssh access are able to ssh in.
# - LDAP users not granted ssh access are unable to ssh in.
# - LDAP users are able to login when their respective passwords have been
#   changed.
#
# >> This test ASSUMES the SIMP server (puppetserver) is also the LDAP server <<

# facts gathered here are executed when the file first loads and
# use the factor gem temporarily installed into system ruby
puppetserver      = only_host_with_role(hosts, 'master')
puppetserver_fqdn = fact_on(puppetserver, 'fqdn')
agents            = hosts_with_role(hosts, 'agent')
ldap_is_389ds     = (fact_on(puppetserver, 'operatingsystemmajrelease') != '7')

# subset of LDAP users for whom we want to execute login tests
ldap_users_with_ssh_access  = [ 'admin2', 'auditor1' ]
ldap_users_without_ssh_access = [ 'user1' ]

describe 'LDAP user access' do

  let(:files_dir) { 'spec/acceptance/common_files' }
  let(:ldap_root_pwd) { test_password(:ldap_root) }
  let(:first_pwd)     { test_password(:user, 0) }
  let(:second_pwd)    { test_password(:user, 1) }

  let(:base_dn) do
    query = "puppet lookup --environment production --node #{puppetserver_fqdn} simp_options::ldap::base_dn"
    on(puppetserver, query).stdout.gsub('---','').gsub('...','').strip
  end

  let(:ldap_groups) {{
    'admin1'     => 3001, # primary group of admin1 user
    'admin2'     => 3002, # primary group of admin2 user
    'auditor1'   => 7001, # primary group of auditor1 user
    'baduser'    => 9001, # primary group of baduser user
    'NotAllowed' => 9999,
    'user1'      => 4001, # primary group of user1 user
    'user2'      => 4002, # primary group of user2 user
    'testgroup'  => 4000,
    'security'   => 7700  # SIMP's auditor group (simp::admin::auditor_group).
                          # Allowed ssh access for historical reasons, but not
                          # created in LDAP by default.
  }}

  let(:ldap_users) {{
    # NOTE:
    # - 'sec_groups' are the secondary groups the users are to be added to
    # - By default, SIMP allows ssh access to users in the 'administrators' and
    #   'security' groups via simp::admin
    'admin1'   => { 'uidNumber' => 3001, 'gidNumber' => 3001, 'sec_groups' => [ 'users', 'administrators'] },
    'admin2'   => { 'uidNumber' => 3002, 'gidNumber' => 3002, 'sec_groups' => [ 'users', 'administrators'] },
    'auditor1' => { 'uidNumber' => 7001, 'gidNumber' => 7001, 'sec_groups' => [ 'security'] },
    'baduser'  => { 'uidNumber' => 9001, 'gidNumber' => 9001, 'sec_groups' => [ 'NotAllowed'] },
    'user1'    => { 'uidNumber' => 4001, 'gidNumber' => 4001, 'sec_groups' => [ 'testgroup', 'users'] },
    'user2'    => { 'uidNumber' => 4002, 'gidNumber' => 4002, 'sec_groups' => [ 'testgroup', 'users'] }
  }}

  let(:extra_script_args) {
    if ldap_is_389ds
      ''
    else
      # scripts to add/modify entries on the OpenLDAP server (EL7) require
      # the LDAP root password
      ldap_root_pwd
    end
  }

  context 'LDAP user creation' do
    let(:puppetserver_yaml) {
      "#{hiera_datadir(puppetserver)}/hosts/#{puppetserver_fqdn}.yaml"
    }

    let(:puppetserver_hieradata) do
      user_password_hash = encrypt_ldap_password(puppetserver, first_pwd)

      puppetserver_hiera = YAML.load(on(puppetserver, "cat #{puppetserver_yaml}").stdout)
      puppetserver_hiera['simp::server::classes'] ||= []
      puppetserver_hiera['simp::server::classes'] << 'site::test_ldap'
      puppetserver_hiera['site::test_ldap::groups'] = ldap_groups
      puppetserver_hiera['site::test_ldap::users'] = ldap_users
      puppetserver_hiera['site::test_ldap::user_password_hash'] = user_password_hash
      puppetserver_hiera
    end


    it 'should update hieradata' do
      create_remote_file(puppetserver, puppetserver_yaml, puppetserver_hieradata.to_yaml)
    end

    it 'should generate LDAP user scripts and any supporting LDIF files' do
      on(puppetserver, 'puppet agent -t', :accept_all_exit_codes => true)
      on(puppetserver, 'ls /root/test_ldap/add_users.sh /root/test_ldap/force_password_reset.sh')
    end

    it 'should create LDAP users' do
      # Pass in the LDAP root password as needed (EL7)
      # >> Don't expose the password like this on a real system! <<
      # >>      This is only for automated testing.              <<
      cmd = "/root/test_ldap/add_users.sh #{extra_script_args}"
      on(puppetserver, cmd)

      # verify existence and group membership of all configured LDAP users
      hosts.each do |host|
        ldap_users.each do |ldap_user,info|
          results = retry_on(host, "id #{ldap_user}",
            :retry_interval => 5, :max_retries => 5, :verbose => true.to_s)
          groups = results.stdout.split('groups=')[1]
          expect(groups).to match(info['gidNumber'].to_s)
          info['sec_groups'].each do |group|
            expect(groups).to match(group)
          end
        end
      end
    end
  end

  context 'LDAP user ssh login' do
    it 'should install expect scripts on puppetserver' do
      # This expect script ssh's to a host as a user and then runs 'date'.
      install_expect_script(puppetserver, "#{files_dir}/ssh_cmd_script")

      # This expect script ssh's to a host as a user and changes the user's password
      # at login
      install_expect_script(puppetserver, "#{files_dir}/ssh_password_change_required_script")
    end

    unless ldap_is_389ds
      # With SIMP configuration, only the OpenLDAP server allows you to set the
      # initial password for a user and *NOT* require the user to change it
      # immediately.

      ldap_users_with_ssh_access.each do |ldap_user|
        hosts.each do |host|
          it "Allowed LDAP user #{ldap_user} should be able to login to #{host} via ssh with initial password" do
            base_cmd ="#{EXPECT_SCRIPT_DIR}/ssh_cmd_script #{ldap_user} #{host.name} #{first_pwd} date"
            cmd = adjust_ssh_ciphers_for_expect_script(base_cmd, puppetserver, host)
            on(puppetserver, cmd)
          end
        end
      end

      it 'should be able to force password resets' do
        # Pass in the LDAP root password as needed (EL7)
        # >> Don't expose the password like this on a real system! <<
        # >>      This is only for automated testing.              <<
        cmd = "/root/test_ldap/force_password_reset.sh #{extra_script_args}"
        on(puppetserver, cmd)
      end
    end

    ldap_users_with_ssh_access.each do |ldap_user|
      it "LDAP user #{ldap_user} should be forced to change password upon login via ssh" do
        base_cmd ="#{EXPECT_SCRIPT_DIR}/ssh_password_change_required_script #{ldap_user} #{agents[0].name} #{first_pwd} #{second_pwd}"
        cmd = adjust_ssh_ciphers_for_expect_script(base_cmd, puppetserver, agents[0])
        on(puppetserver, cmd)
      end

      hosts.each do |host|
        it "LDAP user #{ldap_user} should be able to login to #{host} with new password via ssh" do
          base_cmd ="#{EXPECT_SCRIPT_DIR}/ssh_cmd_script #{ldap_user} #{host.name} #{second_pwd} date"
          cmd = adjust_ssh_ciphers_for_expect_script(base_cmd, puppetserver, host)
          on(puppetserver, cmd)
        end
      end
    end

    ldap_users_without_ssh_access.each do |ldap_user|
      hosts.each do |host|
        it "Not allowed LDAP user #{ldap_user} should not be able to #{host} login via ssh with initial password" do
          base_cmd ="#{EXPECT_SCRIPT_DIR}/ssh_cmd_script #{ldap_user} #{host.name} #{second_pwd} date"
          cmd = adjust_ssh_ciphers_for_expect_script(base_cmd, puppetserver, host)
          on(puppetserver, cmd, :acceptable_exit_codes => [1])
        end
      end

      it "Not allowed LDAP user #{ldap_user} should not be prompted to change password login via ssh with initial password" do
        base_cmd ="#{EXPECT_SCRIPT_DIR}/ssh_password_change_required_script #{ldap_user} #{agents[0].name} #{first_pwd} #{second_pwd}"
        cmd = adjust_ssh_ciphers_for_expect_script(base_cmd, puppetserver, agents[0])
        on(puppetserver, cmd, :acceptable_exit_codes => [1])
      end
    end
  end

  # TODO Should verify simp-doc instructions for configuring user ssh keys work
  skip 'LDAP user ssh login using ssh key'

end
