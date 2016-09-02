SIMP 4.2.1
==========

.. raw:: pdf

  PageBreak

.. contents::
  :depth: 2

.. raw:: pdf

  PageBreak


This release is known to work with:

  * RHEL 6.8 x86_64
  * CentOS 6.8 x86_64


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

Manual Changes Required for Pre-4.2.1 Upgrades
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
  referenced above so that you understand the ramifications of this behavior.

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
  You must have at least **2.2GB** of **free** RAM on your system to upgrade to
  this release.

.. NOTE::
  Upgrading from releases older than 4.0 is not supported.

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

.. NOTE::
The naming convention for Puppet module packages was re-codified from
`pupmod-<module_name>` to `pupmod-<author>-<module_name>`.  This accounts for
a large number of apparent deprecations and additions in this release's RPM
Updates list.


+------------------------------------------------+-----------------+------------------+
| Package                                        | Old Version     | New Version      |
+================================================+=================+==================+
| clamav                                         | 0.99.1-1        | 0.99.2-1         |
+------------------------------------------------+-----------------+------------------+
| clamav-db                                      | 0.99.1-1        | 0.99.2-1         |
+------------------------------------------------+-----------------+------------------+
| clamav-devel                                   | 0.99.1-1        | 0.99.2-1         |
+------------------------------------------------+-----------------+------------------+
| clamav-milter                                  | 0.99.1-1        | 0.99.2-1         |
+------------------------------------------------+-----------------+------------------+
| clamd                                          | 0.99.1-1        | 0.99.2-1         |
+------------------------------------------------+-----------------+------------------+
| dracut-fips-aesni                              | 004-409         | N/A              |
+------------------------------------------------+-----------------+------------------+
| dracut-network                                 | 004-409         | N/A              |
+------------------------------------------------+-----------------+------------------+
| elasticsearch [5]                              | N/A             | 2.3.5-1          |
+------------------------------------------------+-----------------+------------------+
| elasticsearch [noarch]                         | 1.3.2-1         | N/A              |
+------------------------------------------------+-----------------+------------------+
| es2unix                                        | 1.6.1-0         | N/A              |
+------------------------------------------------+-----------------+------------------+
| freeradius                                     | 2.2.6-6         | N/A              |
+------------------------------------------------+-----------------+------------------+
| freeradius-ldap                                | 2.2.6-4         | 2.2.6-6          |
+------------------------------------------------+-----------------+------------------+
| freeradius-utils                               | 2.2.6-4         | 2.2.6-6          |
+------------------------------------------------+-----------------+------------------+
| glib2-devel                                    | N/A             | 2.28.8-5         |
+------------------------------------------------+-----------------+------------------+
| glibc                                          | 2.12-1.166      | 2.12-1.192       |
+------------------------------------------------+-----------------+------------------+
| glibc-common                                   | 2.12-1.166      | 2.12-1.192       |
+------------------------------------------------+-----------------+------------------+
| glibc-devel                                    | 2.12-1.166      | N/A              |
+------------------------------------------------+-----------------+------------------+
| glibc-devel                                    | 2.12-1.192      | N/A              |
+------------------------------------------------+-----------------+------------------+
| glibc-devel                                    | 2.12-1.166      | N/A              |
+------------------------------------------------+-----------------+------------------+
| glibc-devel                                    | 2.12-1.192      | N/A              |
+------------------------------------------------+-----------------+------------------+
| glibc-headers                                  | 2.12-1.166      | 2.12-1.192       |
+------------------------------------------------+-----------------+------------------+
| glibc-static                                   | 2.12-1.166      | 2.12-1.192       |
+------------------------------------------------+-----------------+------------------+
| glibc-utils                                    | 2.12-1.166      | 2.12-1.192       |
+------------------------------------------------+-----------------+------------------+
| globus-callout                                 | 3.13-2          | 3.14-1           |
+------------------------------------------------+-----------------+------------------+
| globus-common                                  | 16.2-1          | 16.4-1           |
+------------------------------------------------+-----------------+------------------+
| globus-gsi-cert-utils                          | 9.11-1          | 9.12-1           |
+------------------------------------------------+-----------------+------------------+
| globus-gsi-proxy-ssl                           | 5.7-2           | 5.8-1            |
+------------------------------------------------+-----------------+------------------+
| globus-gssapi-gsi                              | 11.26-1         | 12.1-1           |
+------------------------------------------------+-----------------+------------------+
| gpxe-bootimgs                                  | 0.9.7-6.14      | 0.9.7-6.15       |
+------------------------------------------------+-----------------+------------------+
| gpxe-roms-qemu                                 | 0.9.7-6.14      | 0.9.7-6.15       |
+------------------------------------------------+-----------------+------------------+
| grafana                                        | N/A             | 3.1.1-1470047149 |
+------------------------------------------------+-----------------+------------------+
| haveged                                        | N/A             | 1.9.1-2          |
+------------------------------------------------+-----------------+------------------+
| kernel                                         | 2.6.32-573.3.1  | 2.6.32-642.1.1   |
+------------------------------------------------+-----------------+------------------+
| kernel-abi-whitelists                          | 2.6.32-573.3.1  | 2.6.32-642.1.1   |
+------------------------------------------------+-----------------+------------------+
| kernel-debug                                   | 2.6.32-573.3.1  | 2.6.32-642.1.1   |
+------------------------------------------------+-----------------+------------------+
| kernel-debug-devel [i686]                      | 2.6.32-642      | N/A              |
+------------------------------------------------+-----------------+------------------+
| kernel-debug-devel                             | 2.6.32-573.3.1  | 2.6.32-642.1.1   |
+------------------------------------------------+-----------------+------------------+
| kernel-devel                                   | 2.6.32-573.3.1  | 2.6.32-642.1.1   |
+------------------------------------------------+-----------------+------------------+
| kernel-doc                                     | 2.6.32-573.3.1  | 2.6.32-642.1.1   |
+------------------------------------------------+-----------------+------------------+
| kernel-firmware                                | 2.6.32-573.3.1  | 2.6.32-642.1.1   |
+------------------------------------------------+-----------------+------------------+
| kernel-headers                                 | 2.6.32-573.3.1  | 2.6.32-642.1.1   |
+------------------------------------------------+-----------------+------------------+
| kibana                                         | 3.1.0.SIMP-0    | N/A              |
+------------------------------------------------+-----------------+------------------+
| lcgdm-libs                                     | 1.8.10-1        | 1.8.11-1         |
+------------------------------------------------+-----------------+------------------+
| lfc-libs                                       | 1.8.10-1        | 1.8.11-1         |
+------------------------------------------------+-----------------+------------------+
| lfc-python                                     | 1.8.10-1        | 1.8.11-1         |
+------------------------------------------------+-----------------+------------------+
| libarchive-devel [i686]                        | 2.8.3-4         | N/A              |
+------------------------------------------------+-----------------+------------------+
| libselinux                                     | 2.0.94-7        | N/A              |
+------------------------------------------------+-----------------+------------------+
| libselinux-devel                               | 2.0.94-7        | N/A              |
+------------------------------------------------+-----------------+------------------+
| libselinux-python                              | 2.0.94-7        | N/A              |
+------------------------------------------------+-----------------+------------------+
| libselinux-utils                               | 2.0.94-7        | N/A              |
+------------------------------------------------+-----------------+------------------+
| lksctp-tools                                   | 1.0.10-7        | N/A              |
+------------------------------------------------+-----------------+------------------+
| logstash                                       | 1.4.2-1_2c0f5a1 | 2.3.4-1          |
+------------------------------------------------+-----------------+------------------+
| logstash-contrib                               | 1.4.2-1_efd53ef | N/A              |
+------------------------------------------------+-----------------+------------------+
| mcollective                                    | 2.8.4-1         | 2.8.9-1          |
+------------------------------------------------+-----------------+------------------+
| mcollective-client                             | 2.8.4-1         | 2.8.9-1          |
+------------------------------------------------+-----------------+------------------+
| mcollective-common                             | 2.8.4-1         | 2.8.9-1          |
+------------------------------------------------+-----------------+------------------+
| mcollective-iptables-common                    | 3.0.1-1         | 3.0.2-1          |
+------------------------------------------------+-----------------+------------------+
| mcollective-puppet-agent                       | 1.7.2-1         | 1.11.1-1         |
+------------------------------------------------+-----------------+------------------+
| mcollective-puppet-client                      | 1.7.2-1         | 1.11.1-1         |
+------------------------------------------------+-----------------+------------------+
| mcollective-puppet-common                      | 1.7.2-1         | 1.11.1-1         |
+------------------------------------------------+-----------------+------------------+
| nscd                                           | 2.12-1.166      | 2.12-1.192       |
+------------------------------------------------+-----------------+------------------+
| nspr [i686]                                    | 4.11.0-1        | N/A              |
+------------------------------------------------+-----------------+------------------+
| nspr                                           | 4.10.8-1        | 4.11.0-1         |
+------------------------------------------------+-----------------+------------------+
| nss [i686]                                     | 3.21.0-8        | N/A              |
+------------------------------------------------+-----------------+------------------+
| nss                                            | 3.19.1-3        | 3.21.0-8         |
+------------------------------------------------+-----------------+------------------+
| nss-softokn [i686]                             | 3.14.3-23       | N/A              |
+------------------------------------------------+-----------------+------------------+
| nss-softokn                                    | 3.14.3-22       | 3.14.3-23        |
+------------------------------------------------+-----------------+------------------+
| nss-softokn-freebl [i686]                      | 3.14.3-23       | N/A              |
+------------------------------------------------+-----------------+------------------+
| nss-softokn-freebl                             | 3.14.3-22       | 3.14.3-23        |
+------------------------------------------------+-----------------+------------------+
| nss-sysinit                                    | 3.19.1-3        | 3.21.0-8         |
+------------------------------------------------+-----------------+------------------+
| nss-tools                                      | 3.19.1-3        | 3.21.0-8         |
+------------------------------------------------+-----------------+------------------+
| nss-util [i686]                                | 3.21.0-2        | N/A              |
+------------------------------------------------+-----------------+------------------+
| nss-util                                       | 3.19.1-1        | 3.21.0-2         |
+------------------------------------------------+-----------------+------------------+
| openssl [i686]                                 | 1.0.1e-48       | N/A              |
+------------------------------------------------+-----------------+------------------+
| openssl                                        | 1.0.1e-42       | 1.0.1e-48        |
+------------------------------------------------+-----------------+------------------+
| openssl-devel [i686]                           | 1.0.1e-48       | N/A              |
+------------------------------------------------+-----------------+------------------+
| openssl-devel                                  | 1.0.1e-42       | 1.0.1e-48        |
+------------------------------------------------+-----------------+------------------+
| pupmod-acpid                                   | 0.0.1-1         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-aide                                    | 4.1.0-9         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-apache                                  | 4.1.1-0         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-auditd                                  | 5.0.0-4         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-augeasproviders                         | 2.1.3-0         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-augeasproviders_apache                  | 2.0.1-0         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-augeasproviders_base                    | 2.0.1-0         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-augeasproviders_core                    | 2.0.1-0         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-augeasproviders_grub                    | 2.3.1-0         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-augeasproviders_mounttab                | 2.0.1-0         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-augeasproviders_nagios                  | 2.0.1-0         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-augeasproviders_pam                     | 2.0.1-0         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-augeasproviders_postgresql              | 2.0.1-0         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-augeasproviders_puppet                  | 2.0.1-0         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-augeasproviders_shellvar                | 2.0.1-0         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-augeasproviders_ssh                     | 2.5.0-0         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-augeasproviders_sysctl                  | 2.1.0-0         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-autofs                                  | 4.1.1-0         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-backuppc                                | 4.1.0-5         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-bfraser-grafana                         | N/A             | 2.5.0-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-cgroups                                 | 1.0.0-7         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-clamav                                  | 4.1.0-8         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-dhcp                                    | 4.1.0-5         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-elasticsearch-elasticsearch             | N/A             | 0.11.0-2016      |
+------------------------------------------------+-----------------+------------------+
| pupmod-elasticsearch-logstash                  | N/A             | 0.6.4-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-electrical-file_concat                  | N/A             | 1.0.1-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-foreman                                 | 0.1.0-1         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-freeradius                              | 5.0.0-0         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-ganglia                                 | 5.0.0-0         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-gfs2                                    | 4.1.0-2         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-herculesteam-augeasproviders            | N/A             | 2.1.3-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-herculesteam-augeasproviders_apache     | N/A             | 2.0.1-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-herculesteam-augeasproviders_base       | N/A             | 2.0.1-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-herculesteam-augeasproviders_core       | N/A             | 2.1.1-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-herculesteam-augeasproviders_grub       | N/A             | 2.3.1-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-herculesteam-augeasproviders_mounttab   | N/A             | 2.0.1-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-herculesteam-augeasproviders_nagios     | N/A             | 2.0.1-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-herculesteam-augeasproviders_pam        | N/A             | 2.0.3-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-herculesteam-augeasproviders_postgresql | N/A             | 2.0.3-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-herculesteam-augeasproviders_puppet     | N/A             | 2.0.2-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-herculesteam-augeasproviders_shellvar   | N/A             | 2.1.1-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-herculesteam-augeasproviders_ssh        | N/A             | 2.5.0-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-herculesteam-augeasproviders_sysctl     | N/A             | 2.1.0-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-iptables                                | 4.1.0-15        | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-jenkins                                 | 4.1.0-6         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-krb5                                    | 4.1.0-3         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-libvirt                                 | 4.1.0-17        | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-logrotate                               | 4.1.0-4         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-mcafee                                  | 4.1.0-2         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-mozilla                                 | 4.1.0-1         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-multipathd                              | 4.1.0-2         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-named                                   | 4.2.0-9         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-network                                 | 4.1.0-6         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-nfs                                     | 4.4.2-0         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-nscd                                    | 5.0.1-0         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-ntpd                                    | 4.1.0-10        | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-oddjob                                  | 1.0.0-2         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-onyxpoint-compliance_markup             | 0.1.0-0         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-onyxpoint-gpasswd                       | 1.0.0-1         | 1.0.0-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-openldap                                | 4.1.4-0         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-openscap                                | 4.2.0-3         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-pam                                     | 4.2.1-0         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-pki                                     | 4.2.1-0         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-polkit                                  | 4.1.0-2         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-postfix                                 | 4.1.0-7         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-pupmod                                  | 6.0.0-24        | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-puppetlabs-apache                       | 1.0.1-2         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-puppetlabs-inifile                      | 1.2.0-1         | 1.5.0-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-puppetlabs-java                         | 1.2.0-0         | 1.2.0-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-puppetlabs-java_ks                      | N/A             | 1.4.0-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-puppetlabs-mysql                        | 2.2.3-1         | 2.2.3-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-puppetlabs-puppetdb                     | N/A             | 5.0.0-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-puppetlabs-puppetlabs_apache            | N/A             | 1.0.1-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-puppetlabs-stdlib                       | N/A             | 4.9.0-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-richardc-datacat                        | 0.6.1-0         | 0.6.2-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-rsync                                   | 4.2.0-5         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-rsyslog                                 | 5.1.0-0         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-saz-memcached                           | 4.0.0-2         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-selinux                                 | 1.0.0-5         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp                                    | 1.2.0-0         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-acpid                              | N/A             | 0.0.2-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-activemq                           | 3.0.0-0         | 3.0.0-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-aide                               | N/A             | 4.1.1-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-apache                             | N/A             | 4.1.5-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-auditd                             | N/A             | 5.0.4-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-autofs                             | N/A             | 4.1.2-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-backuppc                           | N/A             | 4.1.1-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-cgroups                            | N/A             | 1.0.1-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-clamav                             | N/A             | 4.1.1-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-compliance_markup                  | N/A             | 1.0.0-0          |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-dhcp                               | N/A             | 4.1.1-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-elasticsearch                      | 2.0.0-3         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-foreman                            | N/A             | 0.2.0-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-freeradius                         | N/A             | 5.0.2-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-ganglia                            | N/A             | 5.0.0-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-gfs2                               | N/A             | 4.1.1-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-haveged                            | N/A             | 0.3.1-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-iptables                           | N/A             | 4.1.4-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-jenkins                            | N/A             | 4.1.0-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-kibana                             | 3.0.1-5         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-krb5                               | N/A             | 5.0.5-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-libvirt                            | N/A             | 4.1.1-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-logrotate                          | N/A             | 4.1.0-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-logstash                           | 1.0.0-6         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-mcafee                             | N/A             | 4.1.1-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-mcollective                        | 2.3.1-0         | 2.3.2-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-memcached                          | N/A             | 2.8.2-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-mozilla                            | N/A             | 4.1.1-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-multipathd                         | N/A             | 4.1.1-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-named                              | N/A             | 4.3.1-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-network                            | N/A             | 4.1.1-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-nfs                                | N/A             | 4.5.1-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-nscd                               | N/A             | 5.0.1-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-ntpd                               | N/A             | 4.1.0-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-oddjob                             | N/A             | 1.0.0-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-openldap                           | N/A             | 4.1.8-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-openscap                           | N/A             | 4.2.1-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-pam                                | N/A             | 4.2.5-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-pki                                | N/A             | 4.2.3-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-polkit                             | N/A             | 4.1.0-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-postfix                            | N/A             | 4.1.3-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-postgresql                         | N/A             | 4.1.0-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-pupmod                             | N/A             | 6.0.5-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-rsync                              | N/A             | 4.2.2-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-rsyslog                            | N/A             | 5.1.0-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-selinux                            | N/A             | 1.0.3-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-simp                               | N/A             | 1.2.7-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-simp_elasticsearch                 | N/A             | 3.0.1-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-simp_grafana                       | N/A             | 0.1.0-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-simp_logstash                      | N/A             | 2.0.0-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-simpcat                            | N/A             | 5.0.1-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-simplib                            | N/A             | 1.3.1-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-site                               | N/A             | 2.0.1-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-snmpd                              | N/A             | 4.1.0-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-ssh                                | N/A             | 4.1.9-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-sssd                               | N/A             | 4.1.3-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-stunnel                            | N/A             | 4.2.7-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-sudo                               | N/A             | 4.1.2-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-sudosh                             | N/A             | 4.1.1-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-svckill                            | N/A             | 1.1.3-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-sysctl                             | N/A             | 4.2.0-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-tcpwrappers                        | N/A             | 4.1.0-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-tftpboot                           | N/A             | 4.1.2-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-tpm                                | N/A             | 0.0.1-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-upstart                            | N/A             | 4.1.2-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-vnc                                | N/A             | 4.1.0-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-vsftpd                             | N/A             | 5.0.4-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-windowmanager                      | N/A             | 4.1.2-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-xinetd                             | N/A             | 2.1.0-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simp-xwindows                           | N/A             | 4.1.1-2016       |
+------------------------------------------------+-----------------+------------------+
| pupmod-simpcat                                 | 5.0.0-0         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-simplib                                 | 1.2.2-0         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-site                                    | 2.0.0-3         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-snmpd                                   | 4.1.0-5         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-ssh                                     | 4.1.2-0         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-ssh-augeas-lenses                       | 4.1.2-0         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-sssd                                    | 4.1.2-0         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-stunnel                                 | 4.2.1-0         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-sudo                                    | 4.1.0-3         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-sudosh                                  | 4.1.0-4         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-svckill                                 | 1.1.0-0         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-sysctl                                  | 4.2.0-0         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-tcpwrappers                             | 3.0.0-3         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-tftpboot                                | 4.1.0-9         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-tpm                                     | 0.0.1-10        | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-upstart                                 | 4.1.0-5         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-vnc                                     | 4.1.0-4         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-vsftpd                                  | 5.0.0-2         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-windowmanager                           | 4.1.0-3         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-xinetd                                  | 2.1.0-5         | N/A              |
+------------------------------------------------+-----------------+------------------+
| pupmod-xwindows                                | 4.1.0-4         | N/A              |
+------------------------------------------------+-----------------+------------------+
| puppetlabs-java_ks                             | 1.4.0-0         | N/A              |
+------------------------------------------------+-----------------+------------------+
| puppetlabs-postgresql                          | 4.1.0-1.SIMP    | N/A              |
+------------------------------------------------+-----------------+------------------+
| puppetlabs-puppetdb                            | 5.0.0-0         | N/A              |
+------------------------------------------------+-----------------+------------------+
| ruby-ldap                                      | 0.9.7-10        | N/A              |
+------------------------------------------------+-----------------+------------------+
| rubygem-net-ldap                               | 0.2.2-4         | 0.6.1-2          |
+------------------------------------------------+-----------------+------------------+
| rubygem-net-ldap-doc                           | 0.2.2-4         | 0.6.1-2          |
+------------------------------------------------+-----------------+------------------+
| rubygem-simp-cli                               | 1.0.16-0        | 1.0.20-0         |
+------------------------------------------------+-----------------+------------------+
| rubygem-simp-cli-doc                           | 1.0.16-0        | 1.0.20-0         |
+------------------------------------------------+-----------------+------------------+
| simp                                           | 4.2.0-2         | 4.2.0-3          |
+------------------------------------------------+-----------------+------------------+
| simp-bootstrap                                 | 4.2.0-4         | 4.3.1-0          |
+------------------------------------------------+-----------------+------------------+
| simp-utils                                     | 4.1.0-13        | 4.1.1-1          |
+------------------------------------------------+-----------------+------------------+
| syslinux-tftpboot [i686]                       | 4.02-16         | N/A              |
+------------------------------------------------+-----------------+------------------+
| syslinux-tftpboot [x86_64]                     | 4.02-9          | N/A              |
+------------------------------------------------+-----------------+------------------+
| trousers [i686]                                | 0.3.13-2        | N/A              |
+------------------------------------------------+-----------------+------------------+
| tzdata                                         | 2016d-1         | N/A              |
+------------------------------------------------+-----------------+------------------+

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
  do not have to be bootstrapped with a trusted CA certificate. Our packages
  are signed, so this should not be an issue.

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
