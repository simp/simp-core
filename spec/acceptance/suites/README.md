# simp-core Acceptance and integration tests

In this directory there are tests that can be used to test SIMP in it's
entirety, including all non ISO components.

| Suite                    | Category    | Description                                                                              |
| ------------------------ | ----------- | ---------------------------------------------------------------------------------------- |
| default                  | Integration | Uses components from `Puppetfile.tracking`                                               |
| install_from_rpm         | Release     | Uses RPMs from SIMP's packagecloud.io repos                                              |
| install_from_tar         | Release     | Uses RPMs using the tarball from the ISO build process                                   |
| install_from_core_module | Release     | Uses a module build from `metadata.json` and whatever dependencies from the Puppet Forge |
| rpm_docker               | Build       | Used to build the SIMP ISO                                                               |


## Overview

In general, integration tests for SIMP follow the same general procedure:

1. Spin up 3 vagrant boxes, one puppetserver (EL version changes based on
   nodeset) and two clients (one EL6 and one EL7)
2. Install, start and configure the puppetserver
  * This is the step where most tests are different. See the subsections below
   for more details
3. Add all the agents to the puppetserver, and run `puppet agent -t`
   until there are no more changes
4. Modify the puppet environment and run further tests

## Running the tests

1. Set up your environment with a [ruby version manager](https://rvm.io/), [vagrant](https://www.vagrantup.com/), and [VirtualBox](https://www.virtualbox.org/)
2. Install Ruby 2.1.9 (follow the guides from the link above)
3. Install bundler: `gem install bundler`
4. Install other dependencies: `gem install`
5. Run the tests:

```bash
bundle exec rake beaker:suites[<suite>,<nodeset>]
```

There two nodesets per suite, `el7_server` and `el6_server`. They control the
version of EL on the puppetserver.

### default

This test runs `puppet module build` in the root directory of `simp_core`,
building a development version of the simp/simp_core metamodule. Then, it spins
up a puppetserver and trys to install the development version of the module,
using the Puppet Forge as a source for all modules.

However, if there are unreleased components referenced in the `metadata.json`,
the `puppet module install` for the module will fail.


### install_from_rpm

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


### install_from_tar

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


### install_from_core_module

This test runs `puppet module build` in the root directory of `simp_core`,
building a development version of the simp/simp_core metamodule. Then, it spins
up a puppetserver and trys to install the development version of the module,
using the Puppet Forge as a source for all modules.

However, if there are unreleased components referenced in the `metadata.json`,
the `puppet module install` for the module will fail.


### rpm_docker

This suite is used to build a SIMP ISO. Please see the
[SIMP documentation](https://simp.readthedocs.io/en/master/getting_started_guide/ISO_Build/Building_SIMP_From_Source.html)
for more detailed instructions.
