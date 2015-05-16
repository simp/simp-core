# 
# Sets up files to test local rsyncs
#
file { "/tmp/foo":
  ensure => directory,
  owner => 'root',
  group => 'root',
  mode => 750
}

file { "/tmp/foo/bar":
  content => 'foo',
  owner => 'puppet'
}

file { "/tmp/foo/baz":
  content => 'foo',
  group => 'puppet'
}

file { "/tmp/foo/barbaz":
  ensure => link,
  target => "/tmp/foo/bar"
}

#
# Sets up files to 'push' to rsync space
#
file { "/tmp/push":
  ensure => directory,
  owner => 'root',
  group => 'root'
}

file { "/tmp/push/file":
  content => 'pushfile'
}

file { "/tmp/push/link":
  ensure => link,
  target => "/tmp/push/file"
}

file { "/srv/rsync/pushed_files":
  ensure => directory
}

rsync { "local_pull_default":
  source => "/tmp/foo",
  target => "/tmp/local_pull_default"
}
rsync { "local_pull_test":
  source => "/tmp/foo/",
  target => "/tmp/local_pull_test",
  preserve_acl => false,
  preserve_xattrs => false,
  preserve_devices => true,
  timeout => 6,
  copy_links => true,
  preserve_owner => false,
  preserve_group => false,
  size_only => false,
  delete => true,
  bwlimit => 20,
  no_implied_dirs => false,
  logoutput => true,
  exclude => ['foo', 'bar', '.svn/', '.git/']
}

file { "/tmp/local_pull_test":
  ensure => directory
}

file { "/tmp/local_pull_test/delete_me":
  content => 'deleted file',
  notify => Rsync['local_pull_test']
}
