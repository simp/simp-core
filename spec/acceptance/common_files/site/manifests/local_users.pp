class site::local_users(
  String $local_admin = 'localadmin'
) {

  group {$local_admin:
    ensure => 'present',
    gid    => 2001
  }

  user { $local_admin:
    ensure     => 'present',
    gid        => $local_admin,
    home       => "/var/${local_admin}",
    managehome => true,
    uid        => 2001
  }

  pam::access::rule { "allow_${local_admin}":
    users      => [ $local_admin ],
    origins    => ['ALL'],
    permission => '+'
  }

  sudo::user_specification { "sudo_${local_admin}":
    user_list => [ $local_admin ],
    runas     => 'root',
    cmnd      => [ '/bin/su root', '/bin/su - root', '/usr/bin/sudosh' ],
    passwd    => false
  }

}
