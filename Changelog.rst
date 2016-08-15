SIMP 4.2.0-2
============

Changelog
---------

.. raw:: pdf

  PageBreak

.. contents::

.. raw:: pdf

  PageBreak

SIMP 4.2.0-2

**Package**: 4.2.0-2

This release is known to work with:

  * RHEL 6.7 x86_64
  * CentOS 6.7 x86_64

This is a **backwards compatible** release in the 4.X series of SIMP.

Manual Changes Required for Legacy Upgrades
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

* Bugs in the `simplib::secure_mountpoints` class (formerly
  `common::secure_mountpoints`)

.. note::
    This only affects you if you did not have a separate partition for /tmp!

* There were issues in the secure_mountpoints class that caused /tmp and
  /var/tmp to be mounted against the root filesystem. While the new code
  addresses this, it cannot determine if your system has been modified
  incorrectly in the past.

* To fix the issue, you need to do the following:
  - Unmount /var/tmp (may take multiple unmounts)
  - Unmount /tmp (may take multiple unmounts)
  - Remove the 'bind' entries for /tmp and /var/tmp from /etc/fstab
  - Run **puppet** with the new code in place

Deprecations
^^^^^^^^^^^^

* The `simp-sysctl` module will be deprecated in the `4.3.0` release of SIMP.
  Current users should migrate to using the `augeasproviders_sysctl` module
  provided with SIMP going forward.

Significant Updates
^^^^^^^^^^^^^^^^^^^

NSCD Replaced with SSSD
"""""""""""""""""""""""

After a **long** wait, all of the bugs that we discovered in SSSD have been fixed!
Therefore, we have moved to using SSSD as our primary form of caching against
our LDAP server. If you do not use LDAP, SSSD will not be installed by default.

This only applies to systems EL6.7 or EL7+, if you have updated SSSD on a
system earlier than EL6.7, then you will need to set `use_sssd` to `true` in
Hiera.

.. NOTE::
  In the future, support for NSCD will be removed as SSSD is the recommended
  system.

NIST 800-53 Compliance Mapping
""""""""""""""""""""""""""""""

This release adds the ability to map all class and define variables into policy
components and validate that mapping at compile time. Our initial mapping is
against the NIST 800-53r4 and is present in this release.

For more information, see `pupmod_simp_compliance_markup`_ for more
information.

Puppet 4 Support
""""""""""""""""

We have started explicit testing of our modules against `Puppet 4`_. Puppet 3.8 is
slated for `EOL`_ in December 2016 and we plan to move to the `AIO`_ installer in the
next major release of SIMP.

The Foreman
"""""""""""

Support for `The Foreman`_ was included into SIMP core. We needed to create our
own `simp-foreman` module which prevents the destruction of an existing Puppet
environment. This is **not** installed as part of SIMP core but can be added.

Move to Semantic Versioning 2.0.0
"""""""""""""""""""""""""""""""""

All of our components have officially moved to using `Semantic Versioning 2.0.0`_.
This allows us to keep our Puppet Modules and RPMs inline with each other as
well as behaving as the rest of the Puppet ecosystem. This does mean that you
will see version numbers rapidly advancing over time and this should not be a
cause for alarm.

Upgrade Guidance
^^^^^^^^^^^^^^^^

Fully detailed upgrade guidance can be found in the **Upgrading SIMP** portion
of the *User's Guide*.

.. WARNING::
  You must have at least **2.2GB** of **free** RAM on your system to upgrade to
  this release.

.. NOTE::
  Upgrading from releases older than 4.0 is not supported.

Security Announcements
^^^^^^^^^^^^^^^^^^^^^^

CVEs Addressed
""""""""""""""

RPM Updates
^^^^^^^^^^^

+-----------------------------+-------------+-------------+
| Package                     | Old Version | New Version |
+=============================+=============+=============+
| clamav                      | 0.98.7-1    | 0.99-3      |
+-----------------------------+-------------+-------------+
| clamav-data                 | 0.98.7-1    | 0.99-3      |
+-----------------------------+-------------+-------------+
| clamav-data-empty           | 0.98.7-1    | 0.99-3      |
+-----------------------------+-------------+-------------+
| clamav-devel                | 0.98.7-1    | 0.99-3      |
+-----------------------------+-------------+-------------+
| clamav-filesystem           | 0.98.7-1    | 0.99-3      |
+-----------------------------+-------------+-------------+
| clamav-scanner              | 0.98.7-1    | 0.99-3      |
+-----------------------------+-------------+-------------+
| clamav-sysvinit             | 0.98.7-1    | 0.99-3      |
+-----------------------------+-------------+-------------+
| clamav-server               | 0.98.7-1    | 0.99-3      |
+-----------------------------+-------------+-------------+
| clamav-server-systemd       | 0.98.7-1    | 0.99-3      |
+-----------------------------+-------------+-------------+
| clamav-server-sysvinit      | 0.98.7-1    | 0.99-3      |
+-----------------------------+-------------+-------------+
| clamav-server-update        | 0.98.7-1    | 0.99-3      |
+-----------------------------+-------------+-------------+
| facter                      | 2.4.1-1     | 2.4.6-1     |
+-----------------------------+-------------+-------------+
| globus-common               | 15.30-1     | 16.0-1      |
+-----------------------------+-------------+-------------+
| globus-gsi-proxy-core       | 7.7-2       | 7.9-1       |
+-----------------------------+-------------+-------------+
| globus-gsi-sysconfig        | 6.8-2       | 6.9-1       |
+-----------------------------+-------------+-------------+
| globus-gssapi-gsi           | 11.22-1     | 11.26-1     |
+-----------------------------+-------------+-------------+
| hiera                       | 3.0.2-1     | 3.0.5-1     |
+-----------------------------+-------------+-------------+
| mcollective                 | 2.2.3-1     | 2.8.4-1     |
+-----------------------------+-------------+-------------+
| mcollective-client          | 2.2.3-1     | 2.8.4-1     |
+-----------------------------+-------------+-------------+
| mcollective-filemgr-agent   | 1.0.2-1     | 1.1.0-1     |
+-----------------------------+-------------+-------------+
| mcollective-filemgr-client  | 1.0.2-1     | 1.1.0-1     |
+-----------------------------+-------------+-------------+
| mcollective-filemgr-common  | 1.0.2-1     | 1.1.0-1     |
+-----------------------------+-------------+-------------+
| mcollective-iptables-agent  | 3.0.1-1     | 3.0.2-1     |
+-----------------------------+-------------+-------------+
| mcollective-iptables-client | 3.0.1-1     | 3.0.2-1     |
+-----------------------------+-------------+-------------+
| mcollective-iptables-common | 3.0.1-1     | 3.0.2-1     |
+-----------------------------+-------------+-------------+
| mcollective-nrpe-agent      | 3.0.2-1     | 3.1.0-1     |
+-----------------------------+-------------+-------------+
| mcollective-nrpe-client     | 3.0.2-1     | 3.1.0-1     |
+-----------------------------+-------------+-------------+
| mcollective-nrpe-common     | 3.0.2-1     | 3.1.0-1     |
+-----------------------------+-------------+-------------+
| mcollective-sysctl-data     | 2.0.0-1     | 2.0.1-1     |
+-----------------------------+-------------+-------------+
| puppet                      | 3.7.4-1     | 3.8.6-1     |
+-----------------------------+-------------+-------------+
| puppet-dashboard            | 1.2.23-1    | N/A         |
+-----------------------------+-------------+-------------+
| puppet-server               | 3.8.1-1     | N/A         |
+-----------------------------+-------------+-------------+
| puppetserver                | 1.1.1-1     | 1.1.3-1     |
+-----------------------------+-------------+-------------+
| razor-server                | 0.14.1-1    | 1.2.0-1     |
+-----------------------------+-------------+-------------+
| razor-torquebox             | 3.0.1-1     | 3.1.1.10-1  |
+-----------------------------+-------------+-------------+
| rubygem-rake                | N/A         | 0.9.6-25    |
+-----------------------------+-------------+-------------+
| voms                        | 2.0.12-3    | 2.0.13-1    |
+-----------------------------+-------------+-------------+

Fixed Bugs
^^^^^^^^^^

pupmod-simp-activemq
""""""""""""""""""""

* Updated `activemq` to the latest release.
* Removed the `tanukiwrapper` dependency.

pupmod-simp-apache
""""""""""""""""""

* Fixed ordering issues that were discovered when testing the `foreman` module.

pupmod-simp-auditd
""""""""""""""""""

* Fixed an issue where `add_rules` did not disable itself if
  `$::auditd::enable_auditing` was set to `false`.

pupmod-simp-freeradius
""""""""""""""""""""""

* Moved all `2` and `3` paths to `v2` and `v3` paths respectively since the
  original paths were not `Puppet 4`_ safe.

pupmod-simp-ganglia
"""""""""""""""""""

* Fixed several minor bugs found during `Puppet 4`_ testing.

pupmod-simp-nfs
"""""""""""""""

* Ensure that the NFS exports template can handle `ANY` and `all` since these
  can be used in `client_nets` for use with `iptables`.
* Added a temporary class `nfs::lvm2` to ensure that the `lvm2` package is
  updated to the latest version since the `nfs-utils` rpm requires it but has a
  `broken dependency`_.
* Fixed `Puppet 4`_ support.

pupmod-simp-nscd
""""""""""""""""

* Replaced remaining `lsb*` variables.
* Fixed a race condition between `service nscd restart` and
  `service nscd reload`

pupmod-simp-openldap
""""""""""""""""""""

* Fixed several ordering and variable issues discovered when testing for
  `Puppet 4`_
* Fixed numerous issues with nslcd
* Now copy the system certificates to `/etc/nslcd.d` for instances that wish to
  use their own certificates.

pupmod-simp-pki
"""""""""""""""

* Removed the `simip5.test.vm` key which was leftover testing garbage.

pupmod-simp-pupmod
""""""""""""""""""

* Fixed logic errors found when testing `Puppet 4`_
* Configuration changes now notify `Service['puppetmaster']` instead of the
  more efficient `Exec`. This prevents a race condition where the service is
  restarted and the Exec fires before the service has fully restarted.
* Fixed the `puppetserver_*` helper scripts that surfaced due to changes in the
  HTTP responses from the Puppet Server.
* Ensure that the `Service` configuration directory can be changed.

pupmod-simp-rsyslog
"""""""""""""""""""

* Fixed issues found during `Puppet 4`_ testing.

pupmod-simp-simp
""""""""""""""""

* Fixed numerous issues found when testing against `Puppet 4`_.
* Fixed the `nfs_server` default in the `home_client` class which had the
  potential to break automounting.

pupmod-simp-simplib
"""""""""""""""""""

* Confined all facts that break Puppet on Windows.
* Removed `simplib::os_bugfixes` because...it never worked anyway.
* Fixed the `ipv6_enabled` fact to not break if IPv6 is already disabled.
  - Thanks to `Klaas Demter`_ for this patch.
* Fixed issues with the `localusers` function where it was having issues when
  used with Ruby >= 1.9

pupmod-simp-ssh
"""""""""""""""

* Fixed issues with `Puppet 4`_ compilation
  - Thanks to `Carl Caum`_ from `Puppet Labs`_ for this fix.

pupmod-simp-sssd
""""""""""""""""

* Ensure that the `sssd` client libraries are installed even if you're not
  running the `sssd` daemon.
* Removed the erroneous `ldap_chpass_updates_last_change` variable and
  re-normalized the module on the `ldap_chpass_update_last_change` variable.

pupmod-simp-stunnel
"""""""""""""""""""

* Fixed ordering issues in the module.
* Removed the public and private PKI certificates from the chroot jail for
  better system security. This will not remove them on existing systems, it
  will simply not place them there on new installations.

simp-cli
""""""""

* Fixed a bug where pre-placed X.509 certificates would be removed when running
  `simp config`. Custom certificates can now be used out of the box.

simp-core
"""""""""

* Connections to the remote YUM server were disabled by default on the initial
  Puppet server. This prevents issues with bootstrap ordering when not
  installing via ISO.
* Fixed the `unpack_dvd` script to properly check for non-existent directories
  before unpacking the ISO images.
* Fixed a bug where the Hiera `use_ldap` variable was not effective due to
  openldap::pam being included in the Hiera class list.

simp-doc
""""""""

* Spelling errors were corrected.
* The PXE boot section was corrected.
* Directory paths were fixed throughout the document.
* The Security Conop tables were fixed.

DVD
"""
* Fixed a few typos in the `auto.cfg` file.

New Features
^^^^^^^^^^^^

pupmod-onyxpoint-compliance
"""""""""""""""""""""""""""

* The first cut of the compliance mapper module. Will be replaced by a SIMP
  native version in the next release.

pupmod-simp-augeasproviders_grub
""""""""""""""""""""""""""""""""

* Imported the latest version of the upstream `augeasproviders_grub` module.
* Added the ability to fully manage GRUB menu entries in both GRUB 2 and GRUB
  Legacy.

pupmod-simp-augeasproviders_sysctl
""""""""""""""""""""""""""""""""""

* Added the ability to fail silently in the case that a running sysctl item
  cannot be manipulated. This is important in cases such as NFS where the
  appropriate module may not be loaded until it is actually used for the first
  time.

pupmod-simp-java_ks
"""""""""""""""""""

* Updated the module to the latest upstream version to support FIPS mode.

pupmod-simp-mcollective
"""""""""""""""""""""""

* Updated the mcollective from the upstream `voxpupuli/puppet-mcollective`_
  module.
* Enabled `authorization plugin`_ support as a new default.

pupmod-simp-openldap
""""""""""""""""""""

* Fixed the `default.ldif` template to modify the password setting defaults.
  This will **not** affect a running LDAP server.
* Ensure that `use_simp_pki` is now treated as a global catalyst.
* Added support for using external (non-SIMP) certificates.

pupmod-simp-pki
"""""""""""""""

* Allow the PKI content source to be modified so that you have a choice of
  where to pull your certificates.
  - Thanks to `Carl Caum`_ from `Puppet Labs`_ for this patch.

pupmod-simp-rsyslog
"""""""""""""""""""

* Ensure that `use_simp_pki` is now treated as a global catalyst.
* Added support for using templates when sending to remote targets.
* Ensure that all module artifacts are now packaged with the RPM.

pupmod-simp-simplib
"""""""""""""""""""

* Added a `to_string()` function.
* Added a `to_integer()` function.
* Ensure that `use_simp_pki` is now treated as a global catalyst.

pupmod-simp-ssh
"""""""""""""""

* Ensure that `use_simp_pki` is now treated as a global catalyst.

pupmod-simp-stunnel
"""""""""""""""""""

* Ensure that `use_simp_pki` is now treated as a global catalyst.

pupmod-simp-sysctl
""""""""""""""""""

* Migrate to using `augeasproviders_sysctl` for all sysctl activities.
* This module will be deprecated in the next major release of SIMP.

simp-doc
""""""""

* The documentation on setting up redundant LDAP servers was updated.
* A section on using `The Foreman`_ with SIMP was added.

Known Bugs
^^^^^^^^^^

* If you are running libvirtd, when svckill runs it will always attempt to kill
  dnsmasq unless you are deliberately trying to run the dnsmasq service.  This
  does *not* actually kill the service but is, instead, an error of the startup
  script and causes no damage to your system.

.. _AIO: https://docs.puppetlabs.com/puppet/4.4/reference/whered_it_go.html
.. _Carl Caum: https://github.com/ccaum
.. _EOL: https://puppetlabs.com/misc/puppet-enterprise-lifecycle
.. _Klaas Demter: https://github.com/Klaas-
.. _Puppet Labs: https://puppetlabs.com/
.. _Semantic Versioning 2.0.0: http://semver.org/spec/v2.0.0.html
.. _The Foreman: http://theforeman.org/
.. _authorization plugin: https://github.com/puppetlabs/mcollective-actionpolicy-auth
.. _broken dependency: https://bugs.centos.org/view.php?id=10537
.. _pupmod_simp_compliance_markup: https://github.com/simp/pupmod-simp-compliance_markup
.. _puppet 4: https://docs.puppetlabs.com/puppet/4.4/reference/
.. _voxpupuli/puppet-mcollective: https://github.com/voxpupuli/puppet-mcollective
