SIMP Community Edition (CE) 6.2.0-0
===================================

.. raw:: pdf

  PageBreak

.. contents::
  :depth: 2

.. raw:: pdf

  PageBreak

This release is known to work with:

  * RHEL 6.9 x86_64
  * RHEL 7.4 x86_64
  * CentOS 6.9 x86_64
  * CentOS 7.0 1708 x86_64


.. NOTE::

   SIMP CE is expected to migrate to Puppet 5 on, or before, October 30 2018.
   We have not noticed any issues with the latest versions of Puppet 5 but it
   is taking time to get all of our tests updated to work with Puppet 5 for
   full coverage.

   At this point, all vendor support for Puppet 4 will be discontinued as will
   SIMP CE support for Puppet prior to 4.10.4.

   SIMP CE will no longer provide any support for Puppet 4 after after June 30
   2019.

Breaking Changes
----------------

.. WARNING::

   This release of SIMP CE is **NOT** backwards compatible with the 4.X and 5.X
   releases. **Direct upgrades will not work!**

   At this point, do not expect any of our code moving forward to work with
   Puppet 3.

If you find any issues, please `file bugs`_!


Significant Updates
-------------------

.. WARNING::

   Due to various issues with earlier releases of Puppet, SIMP CE will now be
   shipping with, and supporting, puppet 4.10.4+.

   It is strongly recommended that users upgrade their system as soon as they
   are able.

.. NOTE::

   SIMP will begin supporting Hiera v5 out of the box as of SIMP 6.3. This is
   mainly to facilitate compliance enforcement in the infrastructure since
   various versions of Puppet 4 do not work properly with Hiera v3 and
   enforcement.

   No changes will be made to existing configurations but compliance
   enforcement from the ``compliance_markup`` module will not work until an
   upgrade to Hiera v5 is complete.

* UEFI systems should now be fully supported. Please note that you may need to
  adjust your ``tftpboot`` settings to handle your specific UEFI system since
  they are not as universal as the legacy BIOS entries.

* Many module updates simply added support for Puppet 5 and Oracle Enterprise
  Linux. These changes will not be listed individually below.

* Likewise, many modules were updated simply to improve tests. These
  improvements will also not be noted below.

* The ``simp_gitlab`` module no longer supports EL6. This is due to integration
  issues with GitLab that cannot be readily fixed by the module maintance team,
  alone.  The EL community had shown no interest in fixing minor issues with EL6
  in the GitLab platform.

Security Announcements
----------------------

RPM Updates
-----------

* Added the ``toml`` rubygem as an RPM for use with the ``elasticsearch``
  modules.

* Updated to the latest ``5.X`` release of Elasticsearch and Logstash
* Updated the ClamAV packages to 0.100.0-2
* Removed clamav-data-empty which is no longer used

Removed Modules
---------------

pupmod-simp-mcollective and pupmod-simp-activemq
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
* Puppetlabs support for MCollective has been dropped, rendering the SIMP
  modules to support this, ``pupmod-simp-mcollective`` and
  ``pupmod-simp-activemq``, non-functional.

pupmod-simp-jenkins
^^^^^^^^^^^^^^^^^^^

* The ``jenkins`` module has not been updated in quite some time and it is
  unknown if it works with current versions of Jenkins since the team has moved
  to GitLab CI.

pupmod-simp-mcafee
^^^^^^^^^^^^^^^^^^

* This module has not been updated and probably does not work with the latest
  McAfee products so it has been removed from the distribution.

pupmod-puppetlabs-java_ks
^^^^^^^^^^^^^^^^^^^^^^^^^

* All modules that depended on this functionality have been removed from the
  distribution and this dangling dependency is also being removed.


Security Updates
----------------

* The PKI certificates in ``/etc/pki/simp_apps`` are now purged by default so
  that unmanaged certificates are not available if the system is repurposed.


Fixed Bugs
----------

pupmod-simp-aide
^^^^^^^^^^^^^^^^

* Added /etc/logrotate.simp.d to default rules.
* Ensure that the ``package`` install comes before dependent ``exec``
  statements.
* Allow the ``cron`` command to be customized.

pupmod-simp-compliance_markup
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

* Fixed several incorrectly typed parameters
* Consolidated several duplicate entries
* Added missing ``IPT:`` message start to ``simp_rsyslog::default_logs``
* Synchronized CentOS and RHEL STIG settings

pupmod-simp-incron
^^^^^^^^^^^^^^^^^^

* Fixed the permissions on the ``incrond`` service in ``systemd`` to remove
  logged errors.
* No longer manage permissions differently than the vendor RPM to align with
  STIG requirements.

pupmod-simp-iptables
^^^^^^^^^^^^^^^^^^^^

* Updated to match the ``ignore`` parameter on input and output interfaces
* Fixed ``scanblock`` rule ordering to properly ban all hosts that are blocked
  by the rules.
* Fixed some issues in the chain retention and optimization code that would
  cause ``iptables`` to fail to reload in some cases.
* Fixed compilation failures if ``proto`` was specified in the ``defaults``
  section of the options Hash.
* Fixed an issue where a ``jump`` target went to an empty ruleset and the chain
  was dropped.
* Retained all native IPTables ``jump`` points by default.
* Added a *deep rule* comparison on rulesets that are identical based on simple
  checks.
* Remediated potential memory leaks.
* Fixed ordering issues when used with ``firewalld``.
* Matched RPM permissions based on STIG requirements.

pupmod-simp-libvirt
^^^^^^^^^^^^^^^^^^^

* Ensure idempotency by working around the fact that the modprobe changes `-`
  to `_`.

pupmod-simp-named
^^^^^^^^^^^^^^^^^

* Properly override the ``systemd`` service file for ``named-chroot`` instead
  of modifying the vendor provided service file.

pupmod-simp-ntpd
^^^^^^^^^^^^^^^^

* Fixed a bug where ``ntpd::ntpd_options`` was not applied to ``ntpd::servers``
  when ``ntpd::servers`` is an ``Array``

pupmod-simp-pam
^^^^^^^^^^^^^^^

* Change the minimum allowed UID to the one defined in ``/etc/login.defs`` by
  default or ``1000`` if nothing else is defined.
* Replace the removal of ``authconfig`` and ``authconfig-tui`` with the use of a
  ``authconfig`` no-op script, so that tools using ``authconfig`` do not
  break.

pupmod-simp-postfix
^^^^^^^^^^^^^^^^^^^

* Added changes to support the settings required by the STIGs.
* Match the RPM supplied file permissions are required by the STIG.

pupmod-simp-pupmod
^^^^^^^^^^^^^^^^^^

* Allow modification of the ``allow`` and ``deny`` rules for supported
  ``keydist`` auth rules.
* Removed obsolete ``mcollective`` auth rules.
* Changed ``$pki_cacerts_all``'s auth rule from ``*`` to ``certname``.
* Modified the default ``max_active_instances`` configuration to be safer by
  default.
* Make the Puppet Server service name dynamic to work properly with both PE and
  FOSS Puppet.
* Properly disable the ``puppet`` service if running in cron mode. This was not
  disabled before and could contribute to a "thundering herd" issue.
* Fixed the Java ``tmpdir`` path for the ``puppetserver`` which allows runs on
  systems that have been pre-hardened

pupmod-simp-rsync
^^^^^^^^^^^^^^^^^

* Force ``concat`` ordering to be ``numeric`` due to a bug in
  ``puppetlabs-concat`` that reverses the order from the native type provided
  by the same module.

pupmod-simp-rsyslog
^^^^^^^^^^^^^^^^^^^

* Use double quotes to allow evaluation of line returns in strings.
* Added a ``systemd`` service override that fixes an ordering problem with
  older versions of ``rsyslog``.
* Fixed bug that did not allow a TLS encrypted server to be configured to forward
  to a follow-on unencrypted rsyslog server.
* Fixed a bug where removing ``rsyslog::rule`` statements from the catalog
  would not cause the ``rsyslog`` service to restart.
* Clarified documentation around adding files to ``/etc/rsyslog.d``.

pupmod-simp-selinux
^^^^^^^^^^^^^^^^^^^

* ``$selinux::ensure`` now defaults to ``enforcing`` and it used across the
  board instead of ``$simp_options::selinux`` which never behaved as designed.

pupmod-simp-simp
^^^^^^^^^^^^^^^^

* Fixed a bug where if the ``puppet_settings`` fact did not exist, users in the
  ``administrators`` group could ``rm -rf`` any path.
* Fixed the certificate cleaning ``sudo`` rule to point to
  ``$facts['puppet_settings']['main']['ssldir']``.
* Ensure that ``prelink`` is fully disabled when the system is in ``FIPS`` mode
  since the two are incompatible.
* Defined a ``portreserve`` service so that there would no longer be any
  service restart flapping.
* Fixed the permissions on the ``ctrl-alt-del-capture`` service file so that
  warnings would no longer be logged.
* Replace the deprecated ``runpuppet`` script with client Puppet bootstrap scripts
  that are not inappropriately killed by ``systemd``, when executed in highly-loaded
  environments.  These scripts allow the ``systemd`` timeout to be specified and
  provide better error handling and logging.
* On systems with ``systemd``, set the host name in client Puppet bootstrap scripts,
  to prevent issues that can arise when a ``dhcp`` lease expires.  This could cause
  the generated Puppet configuration for the client to use ``localhost`` as the
  client's hostname.
* Ensure that running on unsupported operating systems is completely safe.
* No longer deviate from vendor RPM default permissions per the STIG.
* Changed the mode of ``rc.local`` to ``750``.
* Removed the explicit setting of the ``host_list`` on all
  ``sudo::user_specification`` resources to let the updated module defaults
  handle it appropriately.

pupmod-simp-simp_apache
^^^^^^^^^^^^^^^^^^^^^^^

* Fix the ownership of the configuration files to use the ``owner`` variable
  instead of the ``group`` variable for user ownership.

pupmod-simp-simp_elasticsearch
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

* Add a missing ``simp/pam`` module dependency.

pupmod-simp-simp_gitlab
^^^^^^^^^^^^^^^^^^^^^^^

* Fixed the git ``authorized_keys`` lock problem.
* Dropped all support for CentOS 6 due to issues that kept cropping up during
  integration and the overall lack of support from EL upstream to fix minor
  bugs.
* Automatically opt-out of the GitLab data collection service in accordance
  with NIST 800-53r4 AC-20(1) and SC-38.

pupmod-simp-simp_nfs
^^^^^^^^^^^^^^^^^^^^

* Ensure that users can fully disable ``autofs`` if they choose to.
* Fixed ``systemd`` dependencies.

pupmod-simp-simplib
^^^^^^^^^^^^^^^^^^^

* Fixed the ``puppet_settings`` fact so that the different sections are
  appropriately filled out.
  If not updated, this has been shown to cause the ``puppetserver`` process to be
  unable to restart on package update.
* Fixed ``runlevel`` enforcement so that it activates properly when called.
  Previously, no action would be taken on the running system.
* Added logic to prevent respawn of systemctl isolate if already in progress.
* Added a configurable timeout for changing runlevels based on issues discovered
  in the field with systemctl.
* Fixed bugs in the EL6 runlevel persistence where, in some cases, the runlevel
  line might not be added to /etc/inittab.

pupmod-simp-stunnel
^^^^^^^^^^^^^^^^^^^

* Fixed the ``stunnel`` startup scripts to ensure that they will always
  execute.
* Only emit errors when errors occur during startup.
* Removed the ``init.d`` script on ``systemd`` systems.
* Ensure that the ``stunnel`` service name is set correctly in all instances so
  that ``tcpwrappers`` functions properly.

pupmod-simp-svckill
^^^^^^^^^^^^^^^^^^^

* Add simp_client_bootstrap service to the ignore list. If this is omitted
  from the ignore list, svckill will kill the bootstrap process of SIMP clients
  while they are boostrapping the system.

pupmod-simp-vnc
^^^^^^^^^^^^^^^

* Fixed issues with the ``xinetd`` spawned ``VNC`` sessions where ``'IPv4``
  needed to be set as a flag and the banner needed to be eliminated from the
  connection.

simp-cli
^^^^^^^^

* Move to the updated OS facts for less fragility.
* Update several messages to be more clear to the user.
* Fix setting GRUB passwords on EL6.
* Fix ownership and permission issues on created files.
* Validate all puppet code present prior to bootstrapping.
* Fixed various logging issues.
* Improved validation and error handling.
* Fix ``simp passgen`` processing of all password files and improved password
  generation.
* Properly detect Puppet Enterprise on a system and avoid conflicting
  operations.
* Fixed some tests that were not safe to run on real operating systems.

simp-core
^^^^^^^^^

* Enabled GPG checking for the ISO-configured local filesystem repository by default
* Fixed errors in the ``kickstart`` scriptlets
* SSD devices are better detected by the ``diskdetect.sh`` script
* Removed obsolete ``simp-big`` and ``simp-big-disk-crypt`` kickstart options in EL7
* No longer install ``prelink`` at kickstart time
* Fixed EFI support on the ISO releases
* Removed EL7 references to function keys which no longer are honored
* Fixed the boot directory when ``fips`` is enabled on the ISO

simp-doc
^^^^^^^^

* Remove OBE MCollective references
* Fixed issues in the sample ``tftpboot`` puppet code
* Fixed several broken links
* Rearranged the installation guide to be more user friendly

simp-environment
^^^^^^^^^^^^^^^^

* Added the ``dist`` macro to the package name
* Pre-populate ``/var/simp/environments/simp/site_files/pki_files`` and set the
  permissions appropriately. This fixes the failure of ``simp bootstrap`` on
  systems where the ``root`` user's ``umask`` has already been set to ``077``.
* FakeCA config files were marked as such in the RPM so that they will not be
  overwritten on RPM upgrade.
* Fixed a bug where the ``cacertkey`` file was not being generated in the
  correct location at install time.
* Removed ``simp_options::selinux`` from the scenario hieradata.
* Force a run of ``fixfiles`` in the ``%post`` section of ``simp-environment``.

simp-rsync
^^^^^^^^^^

* Fully support UEFI booting.


New Features
------------

pupmod-simp-compliance_markup
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

* More closely aligned with the latest SSG STIG content.

pupmod-simp-dconf
^^^^^^^^^^^^^^^^^

* Added a module for managing ``dconf`` settings.

pupmod-simp-incron
^^^^^^^^^^^^^^^^^^

* Allow users to define entries for ``incron`` system tables from Hiera.
* Added a native type ``incron_system_table`` to allow for client side path
  glob expansion.

pupmod-simp-libvirt
^^^^^^^^^^^^^^^^^^^

* Use ``kmod::load`` instead of a Ruby script to load the kernel module
* Added a ``libvirt_br_netfilter_loaded`` fact to determine if the
  ``br_netfilter`` kernel module is loaded

pupmod-simp-logrotate
^^^^^^^^^^^^^^^^^^^^^

* Move SIMP-specific logrotate rules to a SIMP-managed configuration
  directory, ``/etc/logrotate.simp.d``, and ensure ``logrotate`` processes
  that directory first. This ensures SIMP rules take priority, when duplicate
  rules are specified (e.g., OS and SIMP rules for ``/var/log/boot.log``.

pupmod-simp-nfs
^^^^^^^^^^^^^^^

* Change all ``stunnel`` connections to use ``stunnel::instance`` to that they
  are not interrupted due to issues with the global ``stunnel`` configuration.
* Added the ability to tweak ``stunnel`` parameters for all NFS connections.
* Ensure that all ``stunnel`` services used with NFS are now dependencies of
  the remote filesystem servers actually being active.
* Add the ability to set ``nfs::client::mount::autodetect_remote`` to override
  all autodetection of whether or not the remote system is the local NFS server.
* Added ``nfs::client::mount::stunnel`` to allow users to dictate the
  ``stunnel`` state for individual connections.

pupmod-simp-ntpd
^^^^^^^^^^^^^^^^

* Add optional management of the ``/etc/ntp/step-tickers`` file.
* Add a ``$package_ensure`` parameter to control the ``ntp`` package version.
* Add management of ``/etc/sysconfig/ntpdate``

pupmod-simp-openldap
^^^^^^^^^^^^^^^^^^^^

* Ensure that ``concat`` ordering is set in ``numeric`` order.

pupmod-simp-openscap
^^^^^^^^^^^^^^^^^^^^

* Add an ``oscap`` fact to collect the following:
  * OpenSCAP Version
  * OpenSCAP Supported Specifications
  * OpenSCAP Profiles from ``/usr/share/xml/scap/*/content/*-ds.xml``

pupmod-simp-pam
^^^^^^^^^^^^^^^

* Add the ability to set ``unlock_time`` to ``never`` for ``pam_faillock.so``.
* Set the default ``cracklib_maxclassrepeat`` to ``3``.
* Allow users to change the password hashing algorithm.
* Allow users to toggle password enforcement for the ``root`` user.

pupmod-simp-pki
^^^^^^^^^^^^^^^

* Purge ``/etc/pki/simp_apps`` by default to clean up old certificates and
  allow users to move this directory target.
* Added a new ``$pki::certname`` parameter that controls the name of the
  certificates in ``keydist`` that will be copied to the client. This is, by
  default, set to ``$trusted['certname']`` but can be changed so that users can
  pull other certificates by default.
* Changed the CA certificate source to be a ``String`` so that ``NSS`` databases or
  ``https`` endpoints can be specified.

pupmod-simp-pupmod
^^^^^^^^^^^^^^^^^^

* Added ``pupmod::master::generate_types`` which adds ``incron`` hooks that
  will automatically run ``puppet generate types`` on your server when
  environments or native types are updated in any environment.

pupmod-simp-resolv
^^^^^^^^^^^^^^^^^^

* Prevent invalid ``resolv.conf`` files from being written.

pupmod-simp-simp
^^^^^^^^^^^^^^^^

* Remove ``prelink`` if it is not enabled.
* Added support for connecting to ``IPA`` servers.
* Removed ``simp::mcollective`` class due to global deprecation.
* Removed group management for the ``root`` user based on feedback.
* Set the ownership and permissions of ``/etc/puppet/puppetdb.conf`` so that
  systems that already have the ``root`` ``umsak`` set to ``077`` work
  properly.
* Added a ``simp::netconsole`` class to allow users to configure the
  ``netconsole`` kernel parameter for boot time logging.
* Split out the ``runpuppet`` logic into a ``bootstrap_simp_client`` script to
  be separate from the startup scripts and work around issues with ``systemd``
  timeouts.
* Added an exponential backoff to the ``bootstrap_simp_client`` script to
  handle cases where a lot of servers are being built at the same time.
* Added Microsoft Windows support to the module that changes where the
  ``simp.version`` file is placed on that platform.

pupmod-simp-simp_docker
^^^^^^^^^^^^^^^^^^^^^^^

* Multiple minor updates mostly surrounding the updates to ``simp/iptables`` to
  make it better work with ``docker``.

pupmod-simp-simp_gitlab
^^^^^^^^^^^^^^^^^^^^^^^

* Add support for the new GitLab 10+ LDAP options, specifically for TLS.

pupmod-simp-simp_grafana
^^^^^^^^^^^^^^^^^^^^^^^^

* Added documentation regarding ``rubygem-puppetserver-toml`` for use with the
  ``simp_grafana`` module.

pupmod-simp-simp_ipa
^^^^^^^^^^^^^^^^^^^^

* Initial release of a module for managing ``IPA`` connectivity settings.
* Does not currently manage ``IPA`` server installation.

pupmod-simp-simp_nfs
^^^^^^^^^^^^^^^^^^^^

* Added the ability to force mounts to point to a remote host.

pupmod-simp-simp_openldap
^^^^^^^^^^^^^^^^^^^^^^^^^

* Allow users to set the ``users`` and ``administrators`` ``GID`` values in the
  ``default.ldif`` file.
* Use concat numeric ordering to allow placement of new modifications in a
  predictable and reliable order.

pupmod-simp-simp_options
^^^^^^^^^^^^^^^^^^^^^^^^

* Add ``simp_options::uid`` and ``simp_options::gid`` since several modules
  require a consistent parameter set for enforcing these items globally.
* Removed ``$simp_options::selinux`` since it never worked as designed and was
  not required by more than one module. This is not considered a breaking
  change since it effectively never had any effect on the system anyway.

pupmod-simp-simplib
^^^^^^^^^^^^^^^^^^^

* Added a ``Simplib::Domain`` data type that validates DNS domains against the
  ``TLD`` restrictions from RFC 3968, Section 2.
* Added a ``login_defs`` custom fact that returns a structured fact for the
  entire contents of ``/etc/login.defs``
* Added an ``ipa`` fact that returns information about connectivity to an
  ``IPA`` server.
* Added a ``prelink`` fact to determine whether or not ``prelink`` is installed
  on the system.
* Updated the ``simplib::ldap::domain_to_dn`` function to allow users to decide
  whether or not they want to upcase the returned LDAP attribute strings.
* Added a ``simplib::reboot_notify`` class to allow users to easily toggle
  global ``reboot_notify`` settings.
* Improved ``reboot_notify`` error handling.
* Allow users to set the log level on ``reboot_notify``.
* Added a ``Simplib::PuppetLogLevel`` data type.
* Updated ``init_ulimit`` to allow it to work properly with ``puppet generate
  types``.
* Added a ``simplib::hash_to_opts`` function which turns a ``Hash`` into a
  ``String`` that mirrors a usual shell command.
* Added a ``simplib::install`` defined type that allows package management
  based on a supplied ``Hash``.
* Added a ``simplib::module_exist`` function to detect the existence of a
  module.
* Ensure that ``systemctl`` is never spawned more than once when attempting to
  change the system ``runlevel``.
* Fixed an issue in EL6 ``runlevel`` persistence where the line may not be
  written to ``/etc/inittab``.

pupmod-simp-ssh
^^^^^^^^^^^^^^^

* Ensure that ``GSSAPIAuthentication`` is disabled if the host is on an ``IPA``
  domain.
* Moved all management of the ``/etc/ssh/ssh_config`` file to use the
  ``ssh_config`` augeasprovider. Management of all SSH configuration files is
  now done consistently.
* Removed the no longer required ``sshd.aug`` augeas lens.
* Added parameter management to the ``sshd_config`` to align with the STIG
  requirements.
* Default to not configure RhostsRSAAuthentication in sshd_config for versions
  of openssh that no longer allow that option.

pupmod-simp-sssd
^^^^^^^^^^^^^^^^

* Updated to use the ``login_defs`` fact to determine the default ``uid_min``
  and ``uid_max`` values.
* Added a defined type for connecting to an ``IPA`` server.
* Added tests for connecting to Active Directory and updated the configuration
  settings appropriately.
* Allow passing ``ldap_tls_cacert`` to the ``sssd::provider::ldap`` defined
  type.
* Align ``sssd`` permissions with the RPM defaults.

pupmod-simp-stunnel
^^^^^^^^^^^^^^^^^^^

* Isolated the ``instance`` logic away from the global ``connection`` logic
  completely.
* Added a native type that cleans up all instances that may have been abandoned
  by ``stunnel::instance``.
* Added parameters to allow controlling ``systemd`` requirement chains.

pupmod-simp-sudo
^^^^^^^^^^^^^^^^

* Added both the short ``hostname`` and long ``fqdn`` to the user access
  control by default.
* Update user_specification define to not accept an empty hostlist.

pupmod-simp-tftpboot
^^^^^^^^^^^^^^^^^^^^

* Added support for UEFI PXEboot
* Moved the ``tftpboot`` root directory from ``/tftpboot`` to
  ``/var/lib/tftpboot`` to match the expectations of SELinux and the STIG.
* Added a ``tftpboot::tftpboot_root_dir`` parameter to all users to override
  the root directory location.

pupmod-simp-tpm
^^^^^^^^^^^^^^^

* Moved the policy ``systemd`` unit files to ``/etc/systemd``
* Ensure that the ``IMA`` service only starts on reboot instead of during a
  puppet run.
* Disabled many ``IMA`` checks by default to make the impact lighter on a
  standard system.

pupmod-simp-useradd
^^^^^^^^^^^^^^^^^^^

* Set the min and max ``UID`` and ``GID`` based on what is in ``login.defs``
  and default to something sensible for the platform.


simp-core
^^^^^^^^^

* Add logic to auto.cfg to use OS-specific GPG keys in simp_filesystem.repo.
* Client kickstart files were updated to use the latest ``simp::server::kickstart``
  API and to provide support for UEFI PXE boot
* EL6 kickstart files were updated to more closely match the EL7 kickstart files

simp-doc
^^^^^^^^

* Added SIMP 6.1.0 to 6.2.0 upgrade guide
* Added SIMP on AWS documentation
* Added a HOWTO for IPA client enrollment
* Added a HOWTO for customizing settings for SSH
* Added documentation on how to disconnect from ``puppetDB``
* Updated the documentation for UEFI PXE booting.
* Clarified certificate management
* Restructured pages for better navigation
* Updated contributors guide to description more details about the development
  workflow

simp-vendored-r10k
^^^^^^^^^^^^^^^^^^

* Added a SIMP vendored version of ``r10k`` that lives at
  ``/usr/share/simp/bin/r10k`` to ensure that a known version of ``r10k`` is
  present on the system at all times. User ``PATH`` environment variables are
  **not** updated so that command must be called directly.


Known Bugs
----------

* There is a bug in ``Facter 3`` that causes it to segfault when printing large
  unsigned integers - `FACT-1732`_

  * This may cause your run to crash if you run ``puppet agent -t --debug``

* The ``krb5`` module may have issues in some cases, validation pending
* The graphical ``switch user`` functionality appears to work randomly. We are
  working with the vendor to discover a solution

.. _FACT-1732: https://tickets.puppetlabs.com/browse/FACT-1732
.. _file bugs: https://simp-project.atlassian.net
