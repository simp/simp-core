#
# rsync fail
#
rsync { "fail_no_files":
  source => "/tmp/uhkdahkiuerolkdsaklkhads",
  target => "/tmp/fail_no_files"
}

notify { "fail_no_files":
  subscribe => Rsync["fail_no_files"]
}

#
# rsync fail
#
rsync { "fail_no_files_no_output":
  source => "/tmp/uhkdahkiuerolkdsaklkhads",
  target => "/tmp/fail_no_files_no_output",
  logoutput => false
}

notify { "fail_no_files_no_output":
  subscribe => Rsync["fail_no_files_no_output"]
}

#
# user but no password
#
/*
rsync { "fail_no_pass":
  server => '127.0.0.1',
  source => 'foo/bar',
  target => '/tmp/fail_no_pass',
  user => 'foo'
}

notify { "fail_no_pass":
  subscribe => Rsync["fail_no_pass"]
}
*/

#
# missing source
#
/*rsync { "fail_no_source":
  target => "/tmp/fail_no_source"
}

notify { "fail_no_source":
  subscribe => Rsync["fail_no_source"]
}
*/
#
# missing target
#
/*rsync { "fail_no_target":
  source => "/tmp/fail_no_target"
}

notify { "fail_no_target":
  subscribe => Rsync["fail_no_target"]
}
*/
#
# missing everything
#
/*
rsync { "missing_everything": }

notify { "missing_everything":
  subscribe => Rsync["missing_everything"]
}
*/
