SIMP 6.1.0-RC1
==============

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


Breaking Changes
----------------

.. WARNING::
   This release of SIMP is **NOT** backwards compatible with the 4.X and 5.X
   releases.  **Direct upgrades will not work!**

   At this point, do not expect any of our code moving forward to work with
   Puppet 3.

If you find any issues, please `file bugs`_!

Breaking Changes Since 6.0.0-0
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

We do not expect any breaking changes to be present in 6.1.0-RC1.

Significant Updates
-------------------

Puppetserver auth.conf
^^^^^^^^^^^^^^^^^^^^^^

If you are upgrading from SIMP-6.0.0-0 to a later version:

* The legacy ``auth.conf`` (``/etc/puppetlabs/puppet/auth.conf``) has been deprecated
* ``pupmod-simp-pupmod`` will back up legacy puppet ``auth.conf`` after upgrade

* The puppetserver's ``auth.conf`` is now managed by Puppet
* You will need to re-produce any custom work done to legacy ``auth.conf`` in the
  new ``auth.conf``, via the ``puppet_authorization::rule`` defined type
* The stock rules are managed in ``pupmod::master::simp_auth``

No Longer Delivering ClamAV DAT Files
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Given the wide spacing of SIMP releases, the team determined that it was
ineffective for us to maintain the ``simp-rsync-clamav`` RPM with upstream
ClamAV DAT file updates.

From this point forward, SIMP will not ship with updated ClamAV DAT files and
we highly recommend updating your DAT files from the authoritative upstream
sources.

SNMP Support Added
^^^^^^^^^^^^^^^^^^

We have re-added SNMP support after a thorough re-assessment and update from
our legacy ``snmp`` module. We now build upon a community module and wrap the
SIMP-specific components on top of it.

Preparing for Puppet 5
^^^^^^^^^^^^^^^^^^^^^^

We are in the process of updating all of our modules to include tests for
Puppet 5 and, so far, things have gone quite well.  Our expectation is that the
update to Puppet 5 will be seamless for existing SIMP 6 installations.

Non-Breaking Version Updates
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Many modules had dependencies that were updated in a manner that was breaking
for the downstream module, but which did not affect the SIMP infrastructure.
This caused quite a few of the SIMP modules to have version updates with no
changes other than an update to the ``metadata.json`` file.

In general, this was due to dropping support for Puppet 3.


Security Announcements
----------------------

* CVE-2017-2299

  * Versions of the puppetlabs-apache module prior to 1.11.1 and 2.1.0 make it
    very easy to accidentally misconfigure TLS trust.
  * SIMP brings in version puppetlabs-apache 2.1.0 to mitigate this issue.


RPM Updates
-----------

+---------------------+-------------+-------------+
| Package             | Old Version | New Version |
+=====================+=============+=============+
| puppet-agent        | 1.8.3-1     | 1.10.6-1    |
+---------------------+-------------+-------------+
| puppet-client-tools | 1.1.0-0     | 1.2.1-1     |
+---------------------+-------------+-------------+
| puppetdb            | 4.3.0-1     | 4.4.0-1     |
+---------------------+-------------+-------------+
| puppetdb-termini    | 4.3.0-1     | 4.4.0-1     |
+---------------------+-------------+-------------+
| puppetserver        | 2.7.2-1     | 2.8.0-1     |
+---------------------+-------------+-------------+


Removed Modules
---------------

pupmod-herculesteam-augeasproviders
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
* This was a meta-module that simply required all other ``augeasproviders_*``
  modules and was both not in use by the SIMP framework and was causing user
  confusion.

pupmod-herculesteam-augeasproviders_base
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
* Has internal bugs and was not in use by any SIMP components


Security Updates
----------------

pupmod-puppetlabs-apache
^^^^^^^^^^^^^^^^^^^^^^^^
* Updated to 2.1.0 to fix CVE-2017-2299


Fixed Bugs
----------

pupmod-simp-aide
^^^^^^^^^^^^^^^^
* Fixed a bug where aide reports and errors were not being sent to syslog
* Now use FIPS-appropriate Hash algorithms when the system is in FIPS mode
* No longer hide AIDE initialization failures during Puppet runs

pupmod-simp-compliance_markup
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
* Fixed an issue where a crash would occur when ``null`` values were in the
  compliance markup data

pupmod-simp-logrotate
^^^^^^^^^^^^^^^^^^^^^
* Ensure that ``nodateext`` is set if the ``dateext`` parameter is set to
  ``false``

pupmod-simp-pam
^^^^^^^^^^^^^^^
* Enable ``pam_tty_audit`` for ``sudo`` commands

pupmod-simp-simp_rsyslog
^^^^^^^^^^^^^^^^^^^^^^^^
* Ensure that ``aide`` and ``snmp`` logs are forwarded to remote syslog servers
  as part of the *security relevant* logs
* Persist ``aide`` logs on the remote syslog server in its own directory since
  the logs can get quite large

pupmod-simp-sssd
^^^^^^^^^^^^^^^^
* Updated the ``Sssd::DebugLevel`` Data Type to handle all variants specified
  in the ``sssd.conf`` man page
* No longer add ``try_inotify`` by default since the auto-detection should
  suffice
* Ensure that an empty ``sssd::domains`` Array cannot be passed and set the
  maximum length to ``255`` characters

pupmod-simp-svckill
^^^^^^^^^^^^^^^^^^^
* Fixed a bug in which ``svckill`` could fail on servers for which there are no
  aliased ``systemd`` services


New Features
------------

pupmod-camptocamp-systemd
^^^^^^^^^^^^^^^^^^^^^^^^^
* Added as a SIMP core module

pupmod-vshn-gitlab
^^^^^^^^^^^^^^^^^^
* Added as a SIMP extra

pupmod-simp-clamav
^^^^^^^^^^^^^^^^^^
* Added the option to not manage ClamAV data **at all**

pupmod-simp-compliance_markup
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
* Converted all of the module data to JSON for efficiency

pupmod-simp-logrotate
^^^^^^^^^^^^^^^^^^^^^
* Made the logrotate target directory configurable

pupmod-simp-pam
^^^^^^^^^^^^^^^
* Changed ``pam_cracklib.so`` to ``pam_pwquality.so`` in EL7 systems

pupmod-simp-pupmod
^^^^^^^^^^^^^^^^^^
* Added a SHA256-based option to generate the minute parameter for a client's
  ``puppet agent`` cron entry based on its IP Address

  * This option is intended mitigate the undesirable clustering of client
    ``puppet agent`` runs, when the number of IPs to be transformed is less
    than the minute range over which the randomization is requested (60) and/or
    the client IPs are not linearly assigned

pupmod-simp-simp_gitlab
^^^^^^^^^^^^^^^^^^^^^^^
* Added as a SIMP extra

pupmod-simp-selinux
^^^^^^^^^^^^^^^^^^^
* Added a reboot notification on appropriate SELinux state changes
* Ensure that a ``/.autorelabel`` file is created on appropriate SELinux state
  changes

  * This capability is *disabled* by default due to issues discovered with the
    autorelabel process in the operating system

pupmod-simp-simp_snmpd
^^^^^^^^^^^^^^^^^^^^^^
* Added SNMP support back into SIMP!

pupmod-simp-simplib
^^^^^^^^^^^^^^^^^^^^^^
* Updated ``rand_cron`` to allow the use of a SHA256-based algorithm
  specifically to improve randomization in systems that have non-linear IP
  address schemes
* Added a ``simplib::assert_metadata_os`` function that will read the
  ``operatingsystem_support`` field of a module's ``metadata.json`` and fail if
  the target OS is not in the supported list

  * This can be globally disabled by setting the variable
    ``simplib::assert_metadata::options`` to ``{ 'enable' => false }``

pupmod-simp-timezone
^^^^^^^^^^^^^^^^^^^^
* Forked ``saz/timezone`` since our Puppet 4 PR was not reviewed and no other
  Puppet 4 support seemed forthcoming

pupmod-simp-tpm
^^^^^^^^^^^^^^^
* Refactoring and updates to make using the TPM module easier and safer
* Addition of an ``instances`` feature to the TPM provider so that ``puppet
  resource tpm_ownership`` works as expected
* Changed the ``owner_pass`` to ``well-known`` by default in ``tpm_ownership``
* Removed ``ensure`` in favor of ``owned`` in ``tpm_ownership``

pupmod-voxpupuli-yum
^^^^^^^^^^^^^^^^^^^^
* Added as a SIMP core module

simp-doc
^^^^^^^^^
* A large number of documentation changes and updates have been made
* It is **HIGHLY RECOMMENDED** that you review the new documentation

simp-rsync
^^^^^^^^^^
* Removed the ``simp-rsync-clamav`` sub-package
  * SIMP will no longer ship with updated ClamAV DAT files

simp-utils
^^^^^^^^^^
* Moved the default LDIF example files out of the ``simp-doc`` RPM and into
  ``simp-utils`` for wider accessibility


Known Bugs
----------

* There is a bug in ``Facter 3`` that causes it to segfault when printing large
  unsigned integers - `FACT-1732`_

  * This may cause your run to crash if you run ``puppet agent -t --debug``

* The ``krb5`` module may have issues in some cases, validation pending
* The graphical ``switch user`` functionality does not work. We are working
  with the vendor to discover a solution
* The upgrade of the ``simp-gpgkeys-3.0.1-0.noarch`` RPM on a SIMP server
  fails to set up the keys in ``/var/www/yum/SIMP/GPGKEYS``.   This problem
  can be worked around by either uninstalling ``simp-gpgkeys-3.0.1-0.noarch``
  prior to the SIMP 6.1.0 upgrade, or reinstalling the newer ``simp-gpgkeys``
  RPM after the upgrade.
* An upgrade of the ``pupmod-saz-timezone-3.3.0-2016.1.noarch`` RPM  to
  the ``pupmod-simp-timezone-4.0.0-0.noarch`` RPM fails to copy the
  installed files into ``/etc/puppetlabs/code/environments/simp/modules``,
  when the ``simp-adapter`` is configured to execute the copy.  This
  problem can be worked around by either uninstalling
  ``pupmod-saz-timezone-3.3.0-2016.1.noarch`` prior to the SIMP 6.1.0
  upgrade, or reinstalling the ``pupmod-simp-timezone-4.0.0-0.noarch`` RPM
  after the upgrade.
* Setting selinux to disabled can cause stunnel daemon fail.  Using
  the permissive mode of selinux does not cause these issues.

Other Upgrade Notices
---------------------
#. *Puppet compiles containing the AIDE database initialization are long*:

   In order to expose AIDE database configuration errors during a Puppet
   compilation, the database initialization is no longer handled as a
   background process.  When the AIDE database must be initialized,
   this can extend the time for a Puppet compilation by several minutes.
   At the console the Puppet compilation will appear to pause at
   ``(/Stage[main]/Aide/Exec[update_aide_db])``.

#. *Guidelines for upgrading and troublehooting*:

   The ``User Guide: Upgrading SIMP`` section of the documentation contains further
   information and should be read before upgrading your system.
   The docs can be found at `Read The Docs`_ on the internet or under
   ``/usr/share/doc`` when installed from ``simp-doc.noarch`` rpm on the iso.


.. _FACT-1732: https://tickets.puppetlabs.com/browse/FACT-1732
.. _Puppet Code Manager: https://docs.puppet.com/pe/latest/code_mgr.html
.. _Puppet Data Types: https://docs.puppet.com/puppet/latest/lang_data_type.html
.. _Puppet Location Reference: https://docs.puppet.com/puppet/4.7/reference/whered_it_go.html
.. _file bugs: https://simp-project.atlassian.net
.. _r10k: https://github.com/puppetlabs/r10k
.. _Read The Docs: https://readthedocs.org/projects/simp
.. _Upgrading a PostgreSQL Cluster: https://www.postgresql.org/docs/9.6/static/upgrading.html
