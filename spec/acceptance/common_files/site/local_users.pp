class site::local_users(
  String $local_admin = 'localadmin'
) {

  # Beaker is **NOT** helpful in this case...
  sshd_config { 'PasswordAuthentication':
    value => 'yes',
    notify  => Service['sshd']
  }

  group {$local_admin:
    ensure => 'present'
  }

  user { $local_admin:
    ensure     => 'present',
    gid        => $local_admin,
    home       => "/var/${local_admin}",
    managehome => true,
    # P@ssw0rdP@ssw0rd
    password   => '$6$rounds=10000$hDSthQpS$bo5vJ.QNtf5XzQxJzNi0bq1e2nAjLm8gS1r8zxxb/nFHyllEPdSAismdHxa78V37aJvw8lbc5Ba4Js/ytbUd8.'
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
