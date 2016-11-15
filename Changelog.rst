SIMP 5.2.1-0
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

This update is backwards-compatible for the SIMP 5.2 releases.

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

Manual Changes Required for Pre-5.1.0 Upgrades
----------------------------------------------

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

* There were no breaking changes in this release.

Significant Updates
-------------------

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

* `CVE-2016-5195`_

  * Dirty COW - A privilege escalation vulnerability in the Linux Kernel

RPM Updates
-----------

+--------------------------------+--------------+---------------------+
| Package                        | Old Version  | New Version         |
+================================+==============+=====================+
| pupmod-cristifalcas-journald   | N/A          | 0.2.2-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-elasticsearch-logstash  | 0.6.4-2016   | 0.6.5-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-acpid              | 0.0.2-2016   | 0.0.3-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-activemq           | 3.0.0-2016   | 3.0.1-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-aide               | 4.1.1-2016   | 4.1.2-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-apache             | 4.1.5-2016   | 4.1.7-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-auditd             | 5.0.4-2016   | 5.1.1-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-autofs             | 4.1.2-2016   | 4.1.4-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-clamav             | 4.1.1-2016   | 4.1.2-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-compliance_markup  | 1.0.0-0      | 1.0.2-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-dhcp               | 4.1.1-2016   | 4.1.2-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-dirtycow           | N/A          | 1.0.1-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-foreman            | 0.2.0-2016   | 0.2.2-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-freeradius         | 5.0.2-2016   | 5.0.3-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-ganglia            | 5.0.0-2016   | 5.0.1-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-haveged            | 0.3.1-2016   | 0.3.2-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-iptables           | 4.1.4-2016   | 4.1.5-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-jenkins            | 4.1.0-2016   | 4.1.1-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-krb5               | 5.0.6-2016   | 5.0.8-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-libreswan          | 0.1.0-2016   | 0.1.2-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-libvirt            | 4.1.1-2016   | 4.1.2-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-logrotate          | 4.1.0-2016   | 4.1.1-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-mcafee             | 4.1.1-2016   | 4.1.2-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-mcollective        | 2.3.2-2016   | 2.4.0-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-mozilla            | 4.1.1-2016   | 4.1.2-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-named              | 4.3.1-2016   | 4.3.3-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-network            | 4.1.1-2016   | 4.1.3-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-nfs                | 4.5.2-2016   | 4.5.3-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-nscd               | 5.0.1-2016   | 5.0.2-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-ntpd               | 4.1.0-2016   | 4.1.1-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-oddjob             | 1.0.0-2016   | 1.0.1-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-openldap           | 4.1.8-2016   | 4.1.9-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-openscap           | 4.2.1-2016   | 4.2.2-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-pam                | 4.2.5-2016   | 4.2.6-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-pki                | 4.2.3-2016   | 4.2.5-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-polkit             | 4.1.0-2016   | 4.1.1-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-postfix            | 4.1.3-2016   | 4.1.5-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-postgresql         | 4.1.0-2016   | 4.1.2-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-pupmod             | 6.0.5-2016   | 6.0.9-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-rsync              | 4.2.2-2016   | 4.2.3-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-rsyslog            | 5.1.0-2016   | 5.1.2-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-selinux            | 1.0.3-2016   | 1.0.4-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-simp               | 1.2.7-2016   | 1.2.10-2016         |
+--------------------------------+--------------+---------------------+
| pupmod-simp-simp_elasticsearch | 3.0.1-2016   | 3.0.3-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-simp_grafana       | 0.1.0-2016   | 0.1.1-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-simpcat            | 5.0.1-2016   | 5.0.2-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-simplib            | 1.3.1-2016   | 1.3.4-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-site               | 2.0.1-2016   | 2.0.2-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-snmpd              | 4.1.0-2016   | 4.1.1-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-ssh                | 4.1.10-2016  | 4.1.13-2016         |
+--------------------------------+--------------+---------------------+
| pupmod-simp-sssd               | 4.1.3-2016   | 4.1.4-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-stunnel            | 4.2.7-2016   | 4.2.9-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-sudo               | 4.1.2-2016   | 4.1.3-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-sudosh             | 4.1.1-2016   | 4.1.2-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-svckill            | 1.1.3-2016   | 1.1.4-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-sysctl             | 4.2.0-2016   | 4.2.1-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-tcpwrappers        | 4.1.0-2016   | 4.1.1-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-tftpboot           | 4.1.2-2016   | 4.1.3-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-tpm                | 0.1.0-2016   | 0.2.0-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-upstart            | 4.1.2-2016   | 4.1.3-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-vnc                | 4.1.0-2016   | 4.1.1-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-vsftpd             | 5.0.4-2016   | 5.0.7-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-windowmanager      | 4.1.2-2016   | 4.1.3-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-xinetd             | 2.1.0-2016   | 2.1.1-2016          |
+--------------------------------+--------------+---------------------+
| pupmod-simp-xwindows           | 4.1.1-2016   | 4.1.2-2016          |
+--------------------------------+--------------+---------------------+
| rubygem-simp-cli               | 1.0.20-0.el7 | 1.0.20-0.el7.centos |
+--------------------------------+--------------+---------------------+
| rubygem-simp-cli-doc           | 1.0.20-0.el7 | 1.0.20-0.el7.centos |
+--------------------------------+--------------+---------------------+
| simp                           | 5.2.0-0      | 5.2.1-0             |
+--------------------------------+--------------+---------------------+
| simp-bootstrap                 | 5.3.2-0      | 5.3.4-0             |
+--------------------------------+--------------+---------------------+
| simp-doc                       | 5.2.0-0      | N/A                 |
+--------------------------------+--------------+---------------------+
| simp-gpgkeys                   | 2.0.0-3.el7  | 2.0.0-3.el7.centos  |
+--------------------------------+--------------+---------------------+
| simp-rsync                     | 5.1.0-3.el7  | 5.1.0-3.el7.centos  |
+--------------------------------+--------------+---------------------+
| simp-rsync-clamav              | 5.1.0-3.el7  | 5.1.0-3.el7.centos  |
+--------------------------------+--------------+---------------------+
| simp-utils                     | 5.0.1-1      | 5.0.1-2             |
+--------------------------------+--------------+---------------------+

RPM Deprecations
----------------

* None

Fixed Bugs
----------

pupmod-simp-auditd
^^^^^^^^^^^^^^^^^^

* Updated to use a specific configuration parameter instead of the presence of
  configured syslog servers to determine whether or not to enable log
  forwarding

pupmod-simp-autofs
^^^^^^^^^^^^^^^^^^

* Updated the ``::autofs::map::entry`` and ``::autofs::map::master`` code to
  work safely with the ``simp cat`` module as well as properly ensuring that
  the ``autofs`` service is restarted when the content of one of the map files
  is changed.

pupmod-simp-ganglia
^^^^^^^^^^^^^^^^^^^

* Fixed an invalid ``concat`` dependency for the ``$auth_user_file``

pupmod-simp-named
^^^^^^^^^^^^^^^^^

* Fixed chroot compatibility with :term:`EL` 7

pupmod-simp-network
^^^^^^^^^^^^^^^^^^^

* Updated to fix issues with Puppet 4

pupmod-simp-nfs
^^^^^^^^^^^^^^^

* Changed the permissions on ``/etc/exports`` to ``644`` which was validated to
  meet existing security requirements

  * Vagrant was dying if it could not read this file as a regular user

pupmod-simp-openldap
^^^^^^^^^^^^^^^^^^^^

* Multiple URIs in Hiera entries were not written into ``ldap.conf``
* The ``DEREF`` configuration value in ``ldap.conf`` was not populated
  correctly

pupmod-simp-pupmod
^^^^^^^^^^^^^^^^^^

* Properly redirect ``STDERR`` in ``puppetagent_cron.erb``
* Fully expanded the ``pupmod::ssldir`` parameter so that ``$vardir`` no longer
  causes issues when showing up in an ``auditd`` configuration file
* Corrected an issue where the ``gem-home`` parameter in ``puppetserver.conf``
  was malformed

pupmod-simp-rsyslog
^^^^^^^^^^^^^^^^^^^

* Enabled forwarding of ``journald`` messages to syslog since :term:`EL` 7.2
  disabled this by default
* Fixed an issue where rules that were no longer managed by the module were not
  correctly purged

pupmod-simp-simp
^^^^^^^^^^^^^^^^

* Ensure that the ``netlabel_tools`` package is installed for the ``netlabel``
  service
* Added the :term:`Elasticsearch` and :term:`Grafana` :term:`GPG` keys to the
  :term:`YUM` configuration

pupmod-simp-simplib
^^^^^^^^^^^^^^^^^^^

* Fixed the ``validate_net_list()`` function when using regex strings against
  IPv6 addresses
* Added support for ``nss-myhostname`` which fixes `issues`_ with hostname lookups
  on :term:`EL` 7+ systems
* Added a ``puppet_settings`` Fact that returns a Hash of all settings on the
  Puppet client system
* Fix issues with calls to the ``Service['named']`` resource

simp-bootstrap
^^^^^^^^^^^^^^

* Changed ``trusted['clientcert']`` to ``trusted['certname']`` in ``hiera.yaml``

simp-cli
^^^^^^^^

* Ensure that ``STDERR`` is properly discarded during shell redirects

simp-core
^^^^^^^^^

* Ensured that ``unpack_dvd`` and ``migrate_to_environments`` properly squashed STDERR
* Corrected the ``pupmod-simp-mcollective`` version that was being built

simp-utils
^^^^^^^^^^

* Removed the dependency on `pssh`_

DVD
^^^

* Removed the first call to ``fips=1`` from the kickstart file since it was
  causing issues with some systems

New Features
------------

pupmod-cristifalcas-journald
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

* Added an upstream ``journald`` management module since EL7 needs tweaking to
  the journal on many systems.

pupmod-simp-auditd
^^^^^^^^^^^^^^^^^^

* Added the syslog ``priority`` and ``facility`` options to ``auditd::config::audisp::syslog``

pupmod-simp-dirtycow
^^^^^^^^^^^^^^^^^^^^

* Adds a notification message if your system is affected by the Dirty COW CVE
* Will **not** attempt to automatically upgrade your kernel!

pupmod-simp-rsyslog
^^^^^^^^^^^^^^^^^^^

* Enabled forwarding of ``journald`` logs to syslog

pupmod-simp-simplib
^^^^^^^^^^^^^^^^^^^

* Added a ``puppet_settings`` Fact that returns a Hash of all settings on the
  Puppet client system

pupmod-simp-tpm
^^^^^^^^^^^^^^^

* Changed the default Storage Root Key password default to ``null`` for
  `PKCS#11`_ and Trusted Boot
* Added a fact ``ima_log_size`` that returns the byte size of the `IMA`_ hash log
  in ``securityfs``
* Added the ability to edit the default `IMA`_ policy

  * Be **very** careful if using this in production

simp-bootstrap
^^^^^^^^^^^^^^

* Mapped `NIST 800-171`_ and `ISO/IEC 27001`_ into the SIMP compliance_map
  baseline

simp-doc
^^^^^^^^

* Added TPM management documentation
* Updated the ELG stack documentation
* Another set of usability updates to the documentation, mostly around building
  the system from scratch

DVD
^^^

* Added `iversion`_ to the default ISO mountpoints that make sense for `IMA`_
  measurement

Known Bugs
----------

* If you are running libvirtd, when ``svckill`` runs it will always attempt to kill
  dnsmasq unless you are deliberately trying to run the dnsmasq service.  This
  does *not* actually kill the service but is, instead, an error of the startup
  script and causes no damage to your system.

.. _CVE-2016-5195: https://web.nvd.nist.gov/view/vuln/detail?vulnId=CVE-2016-5195
.. _EOL: https://puppetlabs.com/misc/puppet-enterprise-lifecycle
.. _NIST 800-171: http://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-171.pdf
.. _ISO/IEC 27001: http://www.iso.org/iso/home/standards/management-standards/iso27001.htm
.. _iversion: https://sourceforge.net/p/linux-ima/wiki/Home/#mounting-filesystems-with-iversion
.. _IMA: https://sourceforge.net/p/linux-ima/wiki/Home/
.. _pssh: https://github.com/robinbowes/pssh
.. _issues: https://bugs.centos.org/view.php?id=10635
.. _PKCS#11: http://trousers.sourceforge.net/pkcs11.html
