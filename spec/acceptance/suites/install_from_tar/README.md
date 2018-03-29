# Install from Tarball test

This test attempts to set up two repos:

1) the simp repo which contains all the puppet modules for a simp deployment
2) the dependency repo that contains rpm used by simp.

Use the following ENV variables to configure the test:

#### `BEAKER_repo`

This is used by 'cloud' set up to determine which package cloud repos to use to
set up the dependencies repo. It defaults to 6_X.

#### `BEAKER_release_tarball`

This can be used to override the simp libraries with either cloud or default.
It should be either
  * a url pointing to a tarball to be downloaded (`http:` or `https:`)
  * a full path to a tarball located on the server running the tests
  * `default`: in it is not set it will look for the tar ball in the DVD_Overlay
    directory under the `simp-core/build` directory


## Running the tests

    * EL7 server: `BEAKER_release_tarball=/path/to/tarball bundle exec rake beaker:suites[install_from_tar,el7_server]`
    * EL6 server: `BEAKER_release_tarball=/path/to/tarball bundle exec rake beaker:suites[install_from_tar,el6_server]`
