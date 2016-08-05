SIMP 5.2.0-0
============

.. raw:: pdf

  PageBreak

.. contents::
  :depth: 2

.. raw:: pdf

  PageBreak


This release is known to work with:

  * RHEL 7.2 x86_64
  * CentOS 7.0 1511 x86_64

This update is backwards-compatible for the SIMP core functionality, but
contains breaking changes in some of the optional modules.

Please read this CHANGELOG thoroughly if you are using the following
components:

  * NFS
  * KRB5
  * MCollective
  * ELK

SIMP 6 is Coming
----------------

Due to Puppet 3.X going `EOL`_ in December of 2016, the SIMP stack will be
releasing SIMP 6 as the next major release.  Among major changes:

  * SIMP 6 will use Puppet 4, which is distributed as a single RPM by the
    Puppet all-in-one (AIO) installer.

  * Starting with 6.0.0, the SIMP numbering scheme will follow Semantic
    Versioning 2.0.0.

  * 6.0.0 and will support all operating systems under that numbering scheme
    henceforth.

Manual Changes Requred for Pre-5.1.0 Upgrades
---------------------------------------------

.. NOTE::
  This only affects you if you did not have a separate partition for ``/tmp``!

* There were issues in the ``secure_mountpoints`` class that caused ``/tmp``
  and ``/var/tmp`` to be mounted against the root filesystem. While the new
  code addresses this, it cannot determine if your system has been modified
  incorrectly in the past.

* To fix the issue, you need to do the following:

  * Unmount ``/var/tmp`` (may take multiple unmounts)
  * Unmount ``/tmp`` (may take multiple unmounts)
  * Remove the ``'bind'`` entries for ``/tmp`` and ``/var/tmp`` from ``/etc/fstab``
  * Run ``puppet`` with the new code in place

SSSD
^^^^

.. WARNING::
  SSSD enforces password strength at **login** time! This means that, should
  you have **old** passwords that do not meet the present password policy on
  the host, you will not be able to authenticate with your old password!

Deprecations
------------

* The ``simp-sysctl`` module will be deprecated in the ``6.0.0`` release of
  SIMP.  Current users should migrate to using the ``augeasproviders_sysctl``
  module provided with SIMP going forward.

Breaking Changes
----------------

NFS
^^^

NFS now supports full integration with Kerberos via the SIMP KRB5 module, or an
external KRB5 resource of your choice.

Please take time to look at the updated NFS profile code in the `simp puppet module`_
as well as the new `acceptance tests for the NFS puppet module`_ for a full
understanding of the new features.

.. NOTE::
  The system should not enable the KRB5 and Stunnel options simultaneously

.. WARNING::
  Bugs discovered during acceptance testing found long standing issues in the
  NFS module that required API breaking changes to remedy. Please carefully
  validate your use of the NFS module as well as your Hiera data.

KRB5
^^^^

The KRB5 module has been **completely rewritten** to support the entire KRB5
stack, including setting up a KDC and auto-creating and distributing keytabs to
all nodes that are known via keydist. Please see the `krb5 module documentation`_
and the :ref:`ug-howto-enable-kerberos` HOWTO for details.

MCollective
^^^^^^^^^^^

The `MCollective`_ module has been updated from the upstream repositories and the
``simp::mcollective`` profile has been updated, per new acceptance tests, to
ensure that MCollective works out of the box. Very little input is now required
to add MCollective to your environment. All usernames and passwords are
randomly generated and you will need to pull the usage passwords out of the
system for your users to be able to connect to ActiveMQ and send commands. The
`simp mcollective acceptance test`_ provides an excellent full stack example of
using the new module.

See ``simp passgen --help`` for usage information.

ELK
^^^

The Elasticsearch, Logstash, and Kibana components have been updated to support
Elasticsearch and Logstash 2.3. Kibana has been replaced by Grafana for inbuilt
LDAP and multi-tenant support.

Please see the new `Elasticsearch, Logstash, and Grafana` documentation for
usage information.

Significant Updates
-------------------

HAVEGED Installed by Default
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Particularly affecting Virtual Machines, the volume of cryptographic operations
that the SIMP system performs by default was causing system entropy to run low
on a regular basis. To fix this, we have incorporated the
`HArdware Volatile Entropy Gathering and Expansion Daemon`_. The ``haveged``
process will use a hardware RNG if present so no risk to hardware generated
entropy is present. We understand that any PRNG system will not effect true
Cryptographic entropy. Please read the document linked above and see the online
discussion around the suitability of HAVEGED if you have concerns.

.. NOTE::
  There is also now a new global catalyst ``use_haveged`` which is enabled by
  default on SIMP systems. If you set this to ``false`` in Hiera, HAVEGED will
  be disabled on your system(s).

ISO Auto-Boot is Now Disabled
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

You must now explicitly select an entry when booting the SIMP ISO. There were
too many instances of the ISO being left mounted and performing a constant
re-install loop without this change.

HTTPS Kickstarts
^^^^^^^^^^^^^^^^

The system now encourages the use of HTTPS kickstarts **by default** to ensure
that any potentially sensitive data is protected in transit.

Client validation is not configured in this case since the SIMP project does
not dictate how you kickstart your system.

See the :ref:`ug-configuring-the-clients` section of the :ref:`simp-user-guide` for
instructions.

UEFI Boot
^^^^^^^^^

The system now supports UEFI booting from the SIMP ISO. This provides better
support for newer systems as well as the foundation for Trusted Boot.


Full Disk Encryption (FDE)
^^^^^^^^^^^^^^^^^^^^^^^^^^

SIMP now provides Full Disk Encryption capabilities directly from the ISO build
and within the supplied kickstart files. Please read the documentation on this
capability as found in the :ref:`ig-disk-encryption` section of the
:ref:`simp-installation-guide`.

.. WARNING::
  The default FDE setup ensures that your systems will automatically boot
  without intervention. For better protection, please read the documentation
  referenced above so that you understand the ramfications of this behavior.

Puppet 4 Support
^^^^^^^^^^^^^^^^

All of our modules have been tested against `Puppet 4`_ and should work in a
Puppet 4 system. SIMP will **natively** ship with Puppet 4 by the end of 2016.

IPSec Support via LibreSwan
^^^^^^^^^^^^^^^^^^^^^^^^^^^

A `libreswan`_ module has been added to provide IPSec support to SIMP. We are
awaiting the advent of X.509-based opportunistic IPSec to have a fully
automated integrated trust system. Presently, half of the connection needs to
know about the remote systems for a successful IPSec connection.

Upgrade Guidance
----------------

Detailed upgrade guidance can be found in the :ref:`ug-howto-upgrade-simp` portion of the
:ref:`simp-user-guide`.

.. WARNING::
  You must have at least **2.4GB** of **free** RAM on your system to upgrade to
  this release.

.. NOTE::
  Upgrading from releases older than 5.0 is not supported.

Security Announcements
----------------------

CVEs Addressed
^^^^^^^^^^^^^^

* `CVE-2015-7331`_

  * Remote Code Execution in mcollective-puppet-agent plugin

* `CVE-2016-2788`_

  * Improper validation of fields in MCollective pings

* `CVE-2016-5696`_

  * ``net/ipv4/tcp_input.c`` in the Linux kernel before 4.7 does not properly
    determine the rate of challenge ACK segments, which makes it easier for
    man-in-the-middle attackers to hijack TCP sessions via a blind in-window
    attack.

RPM Updates
-----------

+------------------------+-------------+-------------+
| Package                | Old Version | New Version |
+========================+=============+=============+
| clamav                 | 0.99-2      | 0.99.2-1    |
+------------------------+-------------+-------------+
| clamav-data            | 0.99-2      | 0.99.2-1    |
+------------------------+-------------+-------------+
| clamav-data-empty      | 0.99-2      | 0.99.2-1    |
+------------------------+-------------+-------------+
| clamav-devel           | 0.99-2      | 0.99.2-1    |
+------------------------+-------------+-------------+
| clamav-filesystem      | 0.99-2      | 0.99.2-1    |
+------------------------+-------------+-------------+
| clamav-scanner         | 0.99-2      | 0.99.2-1    |
+------------------------+-------------+-------------+
| clamav-sysvinit        | 0.99-2      | 0.99.2-1    |
+------------------------+-------------+-------------+
| clamav-server          | 0.99-2      | 0.99.2-1    |
+------------------------+-------------+-------------+
| clamav-server-systemd  | 0.99-2      | 0.99.2-1    |
+------------------------+-------------+-------------+
| clamav-server-sysvinit | 0.99-2      | 0.99.2-1    |
+------------------------+-------------+-------------+
| clamav-server-update   | 0.99-2      | 0.99.2-1    |
+------------------------+-------------+-------------+
| rubygem-stomp          | 1.3.4-2     | 1.3.5-1     |
+------------------------+-------------+-------------+
| rubygem-stomp-doc      | 1.3.4-2     | 1.3.5-1     |
+------------------------+-------------+-------------+
| unbound-libs           | none        | 1.4.20-26   |
+------------------------+-------------+-------------+
| libevent               | none        | 2.0.21-4    |
+------------------------+-------------+-------------+
| libreswan              | none        | 3.15-5      |
+------------------------+-------------+-------------+

Deprecations
------------

* pupmod-simp-kibana

  * Replaced by pupmod-simp-simp_grafana (SIMP profile) and
    pupmod-bfraser-grafana (upstream component)

* pupmod-simp-elasticsearch

  * Replaced by pupmod-simp-simp_elasticsearch (SIMP profile) and
    pupmod-elasticsearch-elasticsearch (upstream component)

* pupmod-simp-logstash

  * Replaced by pupmod-simp-simp_logstash (SIMP profile) and
    pupmod-elasticsearch-logstash (upstream component)

Fixed Bugs
----------

pupmod-simp-apache
^^^^^^^^^^^^^^^^^^

* Fix ``munge_httpd_networks`` to work properly with Ruby >= 1.9
* Ensure that non-SIMP PKI certificates are copied recursively
* Add an explicit **default deny** to the ``apache_limits()`` function

pupmod-simp-auditd
^^^^^^^^^^^^^^^^^^

* Fix the default audit locations for ``wtmp`` and ``btmp`` in the audit rules
* Ensure that audit file locations themselves can be dynamically audited
* Added an audit rule for ``renameat`` to comply with `CCE-26651-0`_

pupmod-simp-freeradius
^^^^^^^^^^^^^^^^^^^^^^

* Fixed scoping issues with variables
* Updated the code to work around incompatibilities with integers in class
  names

pupmod-simp-iptables
^^^^^^^^^^^^^^^^^^^^

* Removed the custom type warning in IPTables when used with Puppet 4
* Fixed a regex rule in Ruby 1.8 (EL6) that caused some rules to be dropped
  silently
* Changed the default provider for iptables services to ``'redhat'`` because the
  Puppet default was not functional

pupmod-simp-named
^^^^^^^^^^^^^^^^^

* Created work-around for https://bugzilla.redhat.com/show_bug.cgi?id=1278082
* Added a named::install class and fixed the ordering across the board

pupmod-simp-nfs
^^^^^^^^^^^^^^^

* Several breaking changes were made
* Stunnel and KRB5 should not be used at the same time
* Removed the ``create_home_dirs`` cron job and migrated it to the
  pupmod-simp-simp module

pupmod-simp-openldap
^^^^^^^^^^^^^^^^^^^^

* Fixed certificate location references in the ``pam_ldap`` configuration file
* Removed the dependency on the ``ruby-ldap`` package
* Ensure that ``Exec[bootstrap_ldap]`` is idempotent
* Ensure that TLS support can be toggled in the ``openldap::client`` class

pupmod-simp-pki
^^^^^^^^^^^^^^^

* Removed the custom type warning in ``simp::pki`` when used with Puppet 4
* Fixed permissions flapping in ``pki_cert_sync``

pupmod-simp-pupmod
^^^^^^^^^^^^^^^^^^

* Ensure that the ``use_iptables`` global catalyst is honored
* Limited the Java heap size used by the Puppetserver to not exceed 12G of RAM
  due to a bug in Trapperkeeper.  This will be lifted once we move to Puppet 4.

pupmod-simp-rsync
^^^^^^^^^^^^^^^^^

* Changed the default provider for iptables services to 'redhat' because the
  Puppet default was not functional
* Ensure that the ``client_nets`` global catalyst is properly honored

pupmod-simp-simp
^^^^^^^^^^^^^^^^

* Set ``svckill`` to ignore ``quotaon`` and ``messagebus`` by default

pupmod-simp-simpcat
^^^^^^^^^^^^^^^^^^^

* Ensure that the **client** ``vardir`` is used instead of the server variable

pupmod-simp-simplib
^^^^^^^^^^^^^^^^^^^

* Remove the custom type warnings from ``ftpusers``, ``reboot_notify``, and
  ``script_umask``
* Fixed an ``nsswitch`` edge case that conflicted with ``sssd``
* Added the ``gdm_version`` fact from the ``xwindows`` module
* Ensure that ``tmpwatch`` installed on EL6 systems

pupmod-simp-sssd
^^^^^^^^^^^^^^^^

* Ensure that the LDAP default certificates are set if using TLS and LDAP

pupmod-simp-stunnel
^^^^^^^^^^^^^^^^^^^

* Ensure that all global catalysts are disabled when appropriate
* The chroot'd PKI certificates were not ordered correctly against the ``pki``
  module when in use

pupmod-simp-svckill
^^^^^^^^^^^^^^^^^^^

* Remove the custom type warnings from the custom type
* ``svckill::ignore`` should not include ``svckill`` by default

pupmod-simp-upstart
^^^^^^^^^^^^^^^^^^^

* Ensure that the ``job.erb`` file kept all hash keys ordered

simp-cli
^^^^^^^^

* Ensure that ``simp passgen`` can use the correct path by default
* Fixed several issues in the ``simp`` command with command line parsing

New Features
------------

pupmod-bfraser-grafana
^^^^^^^^^^^^^^^^^^^^^^

* Initial import of the Grafana module into the SIMP ecosystem

pupmod-elasticsearch-elasticsearch
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

* Updated to the 0.11.0 version of the upstream module

pupmod-elasticsearch-logstash
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

* Updated to the 0.6.4 version of the upstream module

pupmod-puppetlabs-inifile
^^^^^^^^^^^^^^^^^^^^^^^^^

* Updated to the 1.5.0 upstream module

pupmod-richardc-datacat
^^^^^^^^^^^^^^^^^^^^^^^

* Update to version 0.6.2

pupmod-simp-apache
^^^^^^^^^^^^^^^^^^

* Add explicit `haveged`_ support

pupmod-simp-simp_elasticsearch
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

* First release of the rewritten SIMP Elasticsearch component profile (to be
  used in conjunction with the pupmod-elasticsearch-elasticsearch module)

pupmod-simp-simp_grafana
^^^^^^^^^^^^^^^^^^^^^^^^

* Initial release of the SIMP Grafana component profile (to be used in
  conjunction with the pupmod-bfraser-grafana module)

pupmod-simp-haveged
^^^^^^^^^^^^^^^^^^^

* First release of the SIMP HAVEGED module (which is a fork of the
  moding/haveged module)

pupmod-simp-krb5
^^^^^^^^^^^^^^^^

* Full module update
* Supports auto-creation of KRB5 keytabs for all systems
* Added a native type ``krb5kdc_auto_keytabs`` to autogenerate keytabs from the
  SIMP resident PKI certificates

pupmod-simp-libreswan
^^^^^^^^^^^^^^^^^^^^^

* First release of a module for managing `libreswan`_ and IPSEC support

pupmod-simp-simp_logstash
^^^^^^^^^^^^^^^^^^^^^^^^^

* First release of the rewritten SIMP Logstash component profile (to be used in
  conjunction with the pupmod-elasticsearch-logstash module).

pupmod-simp-mcollective
^^^^^^^^^^^^^^^^^^^^^^^

* Our fork of the upstream MCollective module was updated to version 2.3.2

pupmod-simp-named
^^^^^^^^^^^^^^^^^

* Users can modify the chroot path in named-chroot.service
* Added a ``named::install`` class and fixed the ordering across the board

pupmod-simp-nfs
^^^^^^^^^^^^^^^

* Incorporated KRB5 support (optional)
* Fixed numerous logic errors and typos during acceptance testing

pupmod-simp-pam
^^^^^^^^^^^^^^^

* Added support for `pam_tty_audit`_

pupmod-simp-postfix
^^^^^^^^^^^^^^^^^^^

* Added `haveged`_ for entropy generation

pupmod-simp-pupmod
^^^^^^^^^^^^^^^^^^

* Added `haveged`_ for entropy generation

pupmod-simp-selinux
^^^^^^^^^^^^^^^^^^^

* Ensure that ``policycoreutils-python`` is installed by default

pupmod-simp-simp
^^^^^^^^^^^^^^^^

* Ensure that ``SSLVerifyClient`` can be controlled in ``ks.conf``
* Use HTTPS YUM repos by default
* Added the ``create_home_dirs`` script that used to be in the ``nfs`` module

pupmod-simp-ssh
^^^^^^^^^^^^^^^

* Added `haveged`_ for entropy generation
* Ensure that ``semanage`` is used to handle non-standard ports
* Added an ``openssh_version`` fact
* Modified kex algorithm:

  * No longer set kex prior to openssh v 5.7
  * Curve25519 kex only set in openssh v 6.5+


pupmod-simp-stunnel
^^^^^^^^^^^^^^^^^^^

* Added `haveged`_ for entropy generation

pupmod-simp-windowmanager
^^^^^^^^^^^^^^^^^^^^^^^^^

* Ensure that the login banner works in EL7
* Add the ability to remove the login button in Gnome 3

pupmod-simp-xwindows
^^^^^^^^^^^^^^^^^^^^

* Remove the ``gdm_version`` fact (to be placed in ``simplib``)

simp-bootstrap
^^^^^^^^^^^^^^^^^^^^^

* Documented the ``hostgroup`` Hiera usage in the ``hieradata/`` directory
* Recommendation for SHA512 password hashes to be generated for ``localusers``
* Added a ``site_files/`` directory in the ``simp`` environment that will be used
  for all generated files and is intended to be excluded from management by
  r10k or Code Manager. This may need to be moved again in SIMP 6.

simp-cli
^^^^^^^^

* Removed the deprecated ``simp check`` command

simp-core
^^^^^^^^^

* Incorporated the ELG stack in the list of included modules
* Added ``haveged`` to the stack for persistent entropy
* Enable HTTPS kickstarts by default
* Fall back to unvalidated YUM HTTPS connections by default so that new systems
  don't have to be bootstrapped with a trusted CA certificate. Our packages are
  signed, so this should not be an issue.

simp-doc
^^^^^^^^

* Full restructure of the documentation to be less confusing and more concise
  for new users.

DVD
^^^

* Disable ISO auto-boot
* Support UEFI Booting
* Ensure that FIPS can be disabled at initial build
* Provide an option for FDE directly from the ISO

Known Bugs
----------

* If you are running libvirtd, when ``svckill`` runs it will always attempt to kill
  dnsmasq unless you are deliberately trying to run the dnsmasq service.  This
  does *not* actually kill the service but is, instead, an error of the startup
  script and causes no damage to your system.

.. _CCE-26651-0: http://www.scaprepo.com/view.jsp?id=CCE-26651-0
.. _CVE-2015-7331: https://puppet.com/security/cve/cve-2015-7331
.. _CVE-2016-2788: https://puppet.com/security/cve/cve-2016-2788
.. _CVE-2016-5696: https://web.nvd.nist.gov/view/vuln/detail?vulnId=CVE-2016-5696
.. _EOL: https://puppetlabs.com/misc/puppet-enterprise-lifecycle
.. _HArdware Volatile Entropy Gathering and Expansion Daemon: http://www.issihosts.com/haveged/ais31.html
.. _MCollective: https://docs.puppet.com/mcollective/
.. _acceptance tests for the NFS puppet module: https://github.com/simp/pupmod-simp-nfs/tree/master/spec/acceptance/suites
.. _haveged: http://www.issihosts.com/haveged/ais31.html
.. _krb5 module documentation: https://github.com/simp/pupmod-simp-krb5/blob/master/README.rst
.. _libreswan: https://libreswan.org/
.. _pam_tty_audit: https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Security_Guide/sec-Configuring_PAM_for_Auditing.html
.. _puppet 4: https://docs.puppetlabs.com/puppet/4.4/reference/
.. _simp mcollective acceptance test: https://github.com/simp/pupmod-simp-simp/blob/master/spec/acceptance/suites/default/01_mcollective_spec.rb
.. _simp puppet module: https://github.com/simp/pupmod-simp-simp/tree/master/manifests/nfs
