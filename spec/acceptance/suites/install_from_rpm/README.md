# Install from RPM test

This test attempts to set up two repos:

1) the simp repo which contains all the puppet modules for a simp deployment
2) the dependency repo that contains rpm used by simp.

Use the following ENV variables to configure the test:

#### `BEAKER_repo`

  * **default** - if BEAKER_repo is not set this will default to using the
    packagecloud repos version 6_X
  *  **fully qualified path** - if this is set to a fully qualified path, it
    will assume this is a repo file that contains definitions for both the simp
    repo and the simp dependencies repo
  * **version** - if it is defined and does not start with `/` it will assume it
    is an different version for the simp packagecloud

#### `BEAKER_puppet_repo`

  * **default** - false; this means that your repos include a version of puppet
    in them to install. (The package cloud dependency repo has a version of
    puppet in it)
  * **true** - It downloads and installs the puppet repo definition and will use
    the latest version of puppet

## Running the tests

* EL7 server: `bundle exec rake beaker:suites[install_from_rpm,el7_server]`
* EL6 server: `bundle exec rake beaker:suites[install_from_rpm,el6_server]`
