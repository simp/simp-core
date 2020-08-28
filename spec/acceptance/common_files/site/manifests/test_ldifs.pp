#  This creates 3 ldifs in /root/ldifs with test LDAP user setup
#
#  add_test_users.ldif:  Creates LDAP users and groups as follows
#
#    Groups Created
#    admin1
#    admin2
#    NotAllowed
#    Test
#    security
#
#    Users Created   Member Groups
#    admin1          admin1
#    admin2          admin2
#    baduser         NotAllowed
#    user1           Test
#    user2           Test
#    auditor1        security
#
#  modify_test_users.ldif:  Adds users to groups
#
#    User    Groups Added
#    admin1  users, administrators
#    admin2  users, administrators
#    user1   users
#    user2   users
#
# @param $base_dn The LDAP Base DN
# @param $user_password_hash The initial password hash used to set the
#   LDAP 'userPassword field for all users
class site::test_ldifs(
  String      $base_dn               = $::simp_options::ldap::base_dn,
  String      $user_password_hash
) {

  file {  '/root/ldifs':
    ensure  => 'directory',
    owner   => 'root',
    group   => 'root',
    mode    => '0750',
  }

  file {  '/root/ldifs/add_test_users.ldif':
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    content =>  template('site/ldifs/add_test_users.ldif.erb')
  }

  file {  '/root/ldifs/modify_test_users.ldif':
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    content =>  epp('site/ldifs/modify_test_users.ldif.epp')
  }

  file {  '/root/ldifs/force_test_users_password_reset.ldif':
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    content =>  template('site/ldifs/force_test_users_password_reset.ldif.erb')
  }

}
