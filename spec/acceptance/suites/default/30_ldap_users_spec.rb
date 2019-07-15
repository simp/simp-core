require 'spec_helper_integration'

test_name 'LDAP user access'

# There have been SIMP problems in the past in which some LDAP users
# have not been able to login when their respective passwords have
# been changed.  This test is to make sure that regression never occurs!

# facts gathered here are executed when the file first loads and
# use the factor gem temporarily installed into system ruby
master_fqdn = fact_on(master, 'fqdn')
agents      = hosts_with_role(hosts, 'agent')

# subset of LDAP users for whom we want to execute login tests
ldap_users  = [ 'admin2', 'auditor1' ]

describe 'LDAP user access' do

  let(:files_dir) { 'spec/acceptance/common_files' }

  let(:base_dn) do
    query = "puppet lookup --environment production --node #{master_fqdn} simp_options::ldap::base_dn"
    on(master, query).stdout.gsub('---','').gsub('...','').strip
  end

  context 'LDAP user creation' do

    let(:site_module_path) {
      '/etc/puppetlabs/code/environments/production/modules/site'
    }

    let(:puppet_master_yaml) {
      "/etc/puppetlabs/code/environments/production/data/hosts/#{master_fqdn}.yaml"
    }

    let(:puppet_master_hieradata) do
      on(master, "echo -n #{test_password} > /root/slappasswd.tmp")
      password_hash = on(master, "slappasswd -T /root/slappasswd.tmp 2>/dev/null").stdout.strip
      on(master, 'rm -rf /root/slappasswd.tmp')

      master_hiera = YAML.load(on(master, "cat #{puppet_master_yaml}").stdout)
      master_hiera['classes'] << 'site::test_ldifs'
      master_hiera['site::test_ldifs::user_password_hash'] = password_hash
      master_hiera
    end

    it 'should update hieradata' do
      create_remote_file(master, puppet_master_yaml, puppet_master_hieradata.to_yaml)
    end

    it 'should generate ldif files' do
      on(master, 'puppet agent -t', :accept_all_exit_codes => true)
      on(master, 'ls /root/ldifs/add_test_users.ldif /root/ldifs/modify_test_users.ldif /root/ldifs/force_test_users_password_reset.ldif')
    end

    it 'should create LDAP users' do
      # add users
      ldap_cmd = "/usr/bin/ldapadd -Z -x -w #{test_password} -D \"cn=LDAPAdmin,OU=People,#{base_dn}\" -f /root/ldifs/add_test_users.ldif"
      on(master, ldap_cmd)

      # modify some user groups
      ldap_cmd = "/usr/bin/ldapmodify -Z -x -w #{test_password} -D \"cn=LDAPAdmin,OU=People,#{base_dn}\" -f /root/ldifs/modify_test_users.ldif"
      on(master, ldap_cmd)

      # verify existence of LDAP users we are using in this test
      ldap_users.each do |ldap_user|
        on(hosts, "id -u #{ldap_user}")
      end
    end
  end

  context 'LDAP user login' do

    it 'should install expect scripts on master' do
      # This expect script ssh's to a host as a user and then runs 'date'.
      install_expect_script(master, "#{files_dir}/ssh_cmd_script")

      # This expect script ssh's to a host as a user and changes the user's password
      # at login
      install_expect_script(master, "#{files_dir}/ssh_password_change_required_script")
    end

    ldap_users.each do |ldap_user|
      it "LDAP user #{ldap_user} should be able to login via ssh" do
        hosts.each do |host|
          base_cmd ="#{EXPECT_SCRIPT_DIR}/ssh_cmd_script #{ldap_user} #{host.name} #{test_password(0)} date"

          # FIXME: Workaround for SIMP-5082
          cmd = adjust_ssh_ciphers_for_expect_script(base_cmd, master, host)
          on(master, cmd)
        end
      end
    end

    it 'should be able to force password resets' do
      ldap_cmd = "/usr/bin/ldapmodify -Z -x -w #{test_password} -D \"cn=LDAPAdmin,OU=People,#{base_dn}\" -f /root/ldifs/force_test_users_password_reset.ldif"
      on(master, ldap_cmd)
    end

    ldap_users.each do |ldap_user|
      it "LDAP user #{ldap_user} should be forced to change password upon login via ssh" do
        base_cmd ="#{EXPECT_SCRIPT_DIR}/ssh_password_change_required_script #{ldap_user} #{agents[0].name} #{test_password(0)} #{test_password(1)}"

        # FIXME: Workaround for SIMP-5082
        cmd = adjust_ssh_ciphers_for_expect_script(base_cmd, master, agents[0])
        on(master, cmd)
      end
    end

    ldap_users.each do |ldap_user|
      it "LDAP user #{ldap_user} should be able to login with new password via ssh" do
        hosts.each do |host|
          base_cmd ="#{EXPECT_SCRIPT_DIR}/ssh_cmd_script #{ldap_user} #{host.name} #{test_password(1)} date"

          # FIXME: Workaround for SIMP-5082
          cmd = adjust_ssh_ciphers_for_expect_script(base_cmd, master, host)
          on(master, cmd)
        end
      end
    end
  end

end
