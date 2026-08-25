# simp-core Acceptance and Integration Tests

This directory contains

* Numerous test suites that can be used to test SIMP in its entirety, including
  non-module components (aka assets).
* A test suite that builds a SIMP ISO.

| Suite                    | Category    | Brief Description                                                                                      |
| ------------------------ | ----------- | ------------------------------------------------------------------------------------------------------ |
| default                  | Integration | SIMP server+client bootstrap and integration using all `Puppetfile.pinned` components                  |
| ipa                      | Integration | SIMP server+client bootstrap and IPA integration (as clients) using all `Puppetfile.pinned` components |
| simp_lite                | Integration | SIMP server+client bootstrap for the simp_lite scenario using all `Puppetfile.pinned` components       |
| install_from_tar         | Pre-Release | SIMP server+client bootstrap using component RPMs from SIMP ISO build tarball                          |
| install_from_rpm         | Release     | SIMP server+client bootstrap using component RPMs from SIMP's internet repos                           |
| install_from_core_module | Release     | SIMP server+client bootstrap test using SIMP meta-module and `Puppetfile.pinned` assets                |
|                          |             |                                                                                                        |
| rpm_docker               | Build       | SIMP ISO build                                                                                         |


## Overview

In general, the SIMP integration/release test suites follow the same general
procedure:

1. Spin up at least 3 vagrant boxes

   * One puppetserver and 2 clients of adjacent EL versions
     (e.g., 1 EL9 client and 1 EL8 client)
   * EL version of the puppetserver changes based on nodeset.
   * One of the clients is a rsyslog server, whose EL version
     also changes based on nodeset.

2. Configure yum repositories specific to the tests

3. Install modules and assets on the puppetserver

   * This is the step where most tests are different. See the subsections below
     for more details.

4. Configure and bootstrap the puppetserver using `simp config` and
   `simp bootstrap`

5. Add all the agents to the puppetserver, and run `puppet agent -t`
   until there are no more changes

6. Optionally, modify the Puppet environment and run additional tests

The SIMP ISO-building test suite spins up a Docker container for the target OS,
builds/download RPMs, and then builds the ISO.

## Running a Test Suite

1. Set up your environment with a [ruby version manager](https://mise.jdx.dev/), [vagrant](https://www.vagrantup.com/), and a supported hypervisor (libvirt or [VirtualBox](https://www.virtualbox.org/))
2. Install a supported Ruby (3.2 or later)
3. Install bundler: `gem install bundler`
4. Install other dependencies: `bundle install`
5. Determine the environment variables appropriate for your test

   * All integration/(pre-)release tests use PUPPET_VERSION
     and BEAKER_PUPPET_COLLECTION to configure Puppet/OpenVox.
   * Some tests may have test-specific environment variables.  See
     the test descriptions, below, for details.

6. Determine the nodeset appropriate for your test.

   * Each integration/(pre-)release test suite contains a nodeset for each
     supported EL server (`el8_server`, `el9_server`, and `el10_server`;
     `default` is `el9_server`). These nodesets control the EL version of
     both the puppetserver and rsyslog server.
   * The `rpm_docker` test suite contains nodesets for building an ISO for
     various OSes (e.g., `rpm_docker/nodesets/el8.yml`,
     `rpm_docker/nodesets/el9.yml`, `rpm_docker/nodesets/el10.yml`)

7. Run the tests for a suite and selected nodeset.  For example,

```bash
# to run the default suite using OpenVox 8 and an EL9 simp server
export PUPPET_VERSION='~> 8.0'
export BEAKER_PUPPET_COLLECTION='openvox8'
bundle exec rake beaker:suites[default,el9_server]
```

### `default` Suite

The purpose of this test suite is to verify the integration of the latest
modules AND assets specified in Puppetfile.pinned.  Since all the components
are pulled down from their Git repositories for this test suite, it does not
require released components.  In fact, when the `Puppetfile.pinned` is set
to the `master` branches of our component modules, this test suite makes sure
our most up-to-date code is compatible.

This test suite installs and bootstraps the SIMP server, bootstraps SIMP
clients, and then executes the following tests:

1. _Rsyslog integration_:  Stimulates applications to generate events of
   interest, and then verifies the actual application messages get logged
   locally and remotely, as expected.
2. _Local user operations_:  Verifies that local users with root privileges
   can login to the puppetserver and agent nodes via ssh, even after
   changing their passwords.
3. _LDAP user operations_:  Verifies LDAP users can login to the puppetserver
   and agent nodes via ssh, even after changing their passwords.
4. _Key `simp` CLI operations_:

   * Re-configuration (second `simp config`)
   * Re-bootstrap (second `simp bootstrap`)
   * Subset of `simp environment new` operations

5. _Compliance enforcement and reporting_: Enables compliance enforcement and
   reporting via the `simp-compliance_markup` module and then evaluates the
   results.

#### yum repositories enabled

This test enables EPEL, SIMP 6 (simp-community-simp), SIMP 6 dependencies
(simp-community-epel, simp-community-puppet, simp-community-postgresql),
and Puppet repositories.

* The SIMP 6 repositories contain the versions of SIMP, EPEL and Puppet
  application packages integrated and fully tested in the last SIMP release.
* The EPEL and Puppet repositories contain the latest available versions
  of their corresponding packages.
* For Puppet 6 on EL >7, the postgresql AppStream must be disabled or the
  version of required, 9.6, will not install even though it is available
  from the simp-community-postgresql repository.

#### puppetserver installation

Details:

1. Installs assets:

   * Creates a Puppetfile containing only the asset entries from
     `Puppetfile.pinned`
   * Downloads assets to a staging directory via `r10k puppetfile install` of
     the asset Puppetfile
   * Manually completes asset installation using commands that (largely) mimic
     each asset's RPM installation.

2. Installs `puppetserver` RPM.
3. Uses `simp` CLI is used to create the SIMP production omni-environment
   skeleton, minus the Puppetfiles.
4. Installs modules:

   * In the production environment creates a Puppetfile containing only the
     module entries from `Puppetfile.pinned`
   * Downloads modules to the production environment's module directory via
     `r10k puppetfile install` of the module Puppetfile
   * Uses `simp` CLI to fix the permissions of the downloaded modules

#### Environment variables

See [Common Environment Variables](#common-environment-variables)


### `ipa` Suite

The purpose of this test suite is to verify the SIMP server and its clients
can be successfully joined to an IPA domain for which the IPA server was
set up outside of Puppet.

This test suite has one more client server that will also be an IPA server.
The test suite installs and bootstraps the SIMP server and bootstraps SIMP
clients exactly as is done in the `default` Suite.  Then, it does the
following:

1. _IPA server install_:  Manually installs an IPA server on the extra client.
2. _IPA domain join_: Adds all the hosts as IPA clients using the
   ``simp::ipa::install`` class.
3. _IPA operation test_:

   * Verifies IPA has registered all 4 nodes and created DNS entries for them.
   * Verifies an IPA-created user in an IPA-created group can ssh from the IPA
     server into the other hosts, when access is allowed for that group.

#### yum repositories enabled

This test enables EPEL, SIMP 6 (simp-community-simp), SIMP 6 dependencies
(simp-community-epel, simp-community-puppet, simp-community-postgresql),
and Puppet repositories.

* The SIMP 6 repositories contain the versions of SIMP, EPEL and Puppet
  application packages integrated and fully tested in the last SIMP release.
* The EPEL and Puppet repositories contain the latest available versions
  of their corresponding packages.
* For Puppet 6 on EL > 7, the postgresql AppStream must be disabled or the
  version of required, 9.6, will not install even though it is available
  from the simp-community-postgresql repository.

#### puppetserver installation

Details:

1. Installs assets:

   * Creates a Puppetfile containing only the asset entries from
     `Puppetfile.pinned`.
   * Downloads assets to a staging directory via `r10k puppetfile install` of
     the asset Puppetfile.
   * Manually completes asset installation using commands that (largely) mimic
     each asset's RPM installation.

2. Installs `puppetserver` RPM.
3. Uses `simp` CLI is used to create the SIMP production omni-environment
   skeleton, minus the Puppetfiles.
4. Installs modules:

   * In the production environment creates a Puppetfile containing only the
     module entries from `Puppetfile.pinned`
   * Downloads modules to the production environment's module directory via
    `r10k puppetfile install` of the module Puppetfile
   * Uses `simp` CLI to fix the permissions of the downloaded modules

#### Environment variables

See [Common Environment Variables](#common-environment-variables)


### `simp_lite` Suite

The purpose of this test suite is to verify that the simp_lite SIMP scenario
configures the puppetserver and clients as expected, when using the latest
modules AND assets specified in Puppetfile.pinned.  It sets up a server
and client exactly as is done in the `default` suite, but changes the scenario
from `simp` to `simp_lite` in the simp_config.yaml file that is used to configure
the puppetserver during the bootstrap process.

It verifies:

1. A firewall is enabled on the puppetserver but not on the clients.
2. Users can `su` to `root` on the clients if they are not in the `wheel` group.
3. Users not in the `wheel` group cannot `su` to `root` on the puppetserver.
4. Rsyslog works as expected.
5. LDAP works as expected.
6. The puppetserver is configured with FIPS enabled, but the clients are not.

Still to do: Verify that the selinux module is not enabled on the clients but is
enabled on the puppetserver.

#### yum repositories enabled

See [yum repositories set up for default Suite](#yum-repositories-enabled)

#### puppetserver installation

See [puppetserver installation for default Suite](#puppetserver-installation)

#### Environment variables

See [Common Environment Variables](#common-environment-variables)


### `install_from_rpm` Suite

The purpose of this test suite is to verify the integration of the latest RPMs
published to the SIMP internet repositories, which effectively verifies non-ISO
RPM installation of SIMP.

This test suite installs and bootstraps the SIMP server and bootstraps SIMP
clients.

#### yum repositories enabled

This test enables SIMP 6 (simp-community-simp) and SIMP 6 dependencies
(simp-community-epel, simp-community-puppet, simp-community-postgresql)
repositories.  It explicitly does not enable the EPEL or Puppet repositories,
as the test expects the EPEL and Puppet RPMs required for SIMP to be available
in the corresponding SIMP 6 dependencies repositories.

#### puppetserver installation

Details:

1. Installs `puppetserver` RPM.
2. Installs assets and modules:

   * Installs asset and module RPMs into `/usr/share/simp` by installing
     the `simp` and `simp-adapter` RPMs.
   * Defers creation of the SIMP production omni environment with Puppetfiles
     and installed modules to `simp config`.

NOTE: If there are unreleased components required by the `simp` RPM, its
installation will fail.

#### Environment variables

See [Common Environment Variables](#common-environment-variables)


### `install_from_tar` Suite

The purpose of this test suite is to verify the integration of a pre-release
set of SIMP component RPMs, prior to publishing the RPMs to the SIMP internet
repositories.  It verifies non-ISO RPM installation of SIMP.

This test suite installs and bootstraps the SIMP server and bootstraps SIMP
clients.

#### yum repositories enabled

This test enables EPEL, SIMP 6 (simp-community-simp for simp-vendored-r10k
packages), SIMP 6 dependencies (simp-community-epel, simp-community-puppet,
simp-community-postgresql), and Puppet repositories.  It also creates and
enables a local repository containing the component RPMs packaged in the
SIMP release tarball.

* The SIMP 6 repositories contain the versions of SIMP, EPEL and Puppet
  application packages integrated and fully tested in the last SIMP release.
* The EPEL and Puppet repositories contain the latest available versions
  of their corresponding packages.
* For Puppet 6 on EL >7, the postgresql AppStream must be disabled or the
  version of required, 9.6, will not install even though it is available
  from the simp-community-postgresql repository.

#### puppetserver installation

Details:

1. Installs `puppetserver` RPM.
2. Installs assets and modules:

   * Installs asset and module RPMs into `/usr/share/simp` by installing
     the `simp` and `simp-adapter` RPMs.
   * Defers creation of the SIMP production omni environment with Puppetfiles
     and installed modules to `simp config`.

#### Environment variables

See [Common Environment Variables](#common-environment-variables)

##### `BEAKER_release_tarball`

The `tar.gz` file containing SIMP component RPMs that is built during
the SIMP ISO building process.

* **unset** - The test will glob for a tarball in the DVD_Overlay directory
  under the `simp-core/build` directory, where the build process would leave it
* **url** - A full URL to a tarball
* **path** - A file location on the machine running this test


### `install_from_core_module` Suite

The purpose of this test suite is to verify the integration of the latest SIMP
Puppet modules published to PuppetForge.

This test suite installs and bootstraps the SIMP server and bootstraps SIMP
clients.

#### yum repositories enabled

See [yum repositories set up for default Suite](#yum-repositories-enabled)

#### puppetserver installation

Details:

1. Installs assets:

   * Creates a Puppetfile containing only the asset entries from
     `Puppetfile.pinned`
   * Downloads assets to a staging directory via `r10k puppetfile install` of
     the asset Puppetfile
   * Manually completes asset installation using commands that (largely) mimic
     each asset's RPM installation.

2. Installs `puppetserver` RPM.
3. Uses `simp` CLI is used to create the SIMP production omni-environment
   skeleton, minus the Puppetfiles.
4. Installs modules:

   * Locally creates the `simp-simp_core` meta-module archive.
   * Uses `puppet module install` of this meta-module archive to install SIMP
     modules from PuppetForge.
   * Uses `simp` CLI to fix the permissions of the downloaded modules

NOTE: If there are unreleased components referenced in the `metadata.json` of
the `simp/simp_core` metamodule, the `puppet module install` for the module will
fail.

#### Environment variables

See [Common Environment Variables](#common-environment-variables)


### `rpm_docker` Suite

This suite is used to build a SIMP ISO. Please see the
[SIMP documentation](https://simp.readthedocs.io/en/master/getting_started_guide/ISO_Build/Building_SIMP_From_Source.html)
for more detailed instructions.

### Common Environment Variables

Below are common environment variables used in the integration/(pre-)release test
suites.

#### `BEAKER_repo`

* Only applies if SIMP or SIMP dependencies repo is enabled in a test suite.
* **unset** - If unset, the test will use the SIMP 6_X repos on PackageCloud,
  if those repos are enabled
* **fully qualified path** -

  - The test will *assume* this is a repo file that contains definitions for the
    SIMP repo and/or the SIMP dependencies repo.  No SIMP internet repos will be
    configured.
  - (Interim) repo files for the yum repos at
    ``https://download.simp-project.com/simp/yum`` can be found in the
    ``spec/acceptance/repo_files`` directory.  Since the repositories pointed to
    by these files are being reconfigured, you may have to update these files.

* **version** - If set, and does not start with `/`, the test will assume it
  is an different version for the SIMP PackageCloud repos.

#### `BEAKER_puppet_repo`

* Only applies if the Puppet/OpenVox repo is enabled in a test suite.
* **unset** - Defaults to `true`
* **true** - The test will install the release repo for the collection
  specified by BEAKER_PUPPET_COLLECTION.  OpenVox collections come from
  [yum.voxpupuli.org](https://yum.voxpupuli.org/) and legacy Puppet
  collections from [yum.puppet.com](https://yum.puppet.com/).
* **false** - Overrides the test set up and does not install the repo.

#### `BEAKER_PUPPET_COLLECTION`

The Puppet/OpenVox collection, e.g. `openvox8` or `puppet8`.

* Only applies if the Puppet/OpenVox repo is enabled in a test suite.
* **unset** - Defaults to 'openvox8'
