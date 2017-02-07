SIMP 6.0.0-Beta
===============

.. raw:: pdf

  PageBreak

.. contents::
  :depth: 2

.. raw:: pdf

  PageBreak


This release is known to work with:

  * RHEL 6.8 x86_64
  * RHEL 6.8 x86_64
  * RHEL 7.3 x86_64
  * CentOS 7.0 1611 x86_64

Breaking Changes
----------------

.. WARNING::
  This release of SIMP is **NOT** backwards compatible with previous releases.
  Direct updates will not work.

  At this point, do not expect any of our code moving forward to work with
  Puppet 3.

.. NOTE::
  This is a **BETA** release

  We currently believe that everything is feature complete but it may take a
  small amount of time for the documentation and support scripts to catch up.

If you find any issues, please `file bugs`_!

.. NOTE::
  If you are working to integrate SIMP into Puppet Enterprise, these are the
  modules that you need to use since they are Puppet 4 compatible.

Paths
^^^^^

Puppet AIO Paths
""""""""""""""""

The system has been updated to use the Puppet AIO paths. Please see the
`Puppet Location Reference`_ for full details.

SIMP Installation Paths
"""""""""""""""""""""""

For better integration with `r10k`_ and `Puppet Code Manager`_, SIMP now installs all
materials in ``/usr/share/simp`` by default.

A script ``simp_rpm_helper`` has been added to copy the ``environment`` and
`module` data into place at ``/etc/puppetlabs/code`` **if configured to do so**.

On the ISO, this configuration is done by default and will be set to
auto-update for all future RPM updates. If you wish to disable this behavior,
you should edit the options in ``/etc/simp/adapter_config.yaml``.

.. NOTE::
   Anything that is in a Git or Subversion repository in the ``simp`` environment
   will **NOT** be overwritten by ``simp_rpm_helper``.

SIMP Dynamic Content Paths
""""""""""""""""""""""""""

To ensure that SIMP dynamic content (ssh keys, generated passwords) are not
mixed with Git-managed infrastructure, the SIMP dynamic content has been moved
to the top level of the environment directory under ``simp_autofiles``.

SIMP Rsync Paths
""""""""""""""""

The SIMP Rsync subsystem now fully supports multiple environments. All
environment-relevant materials have been moved to
``/var/simp/environments/simp/rsync``.

SIMP Partitioning Scheme
""""""""""""""""""""""""

SIMP no longer creates a ``/srv`` partition on EL 6 or 7. ``/var`` has assumed
the role of ``/srv``. The root partition size has been increased from 4GB to
10GB.

Significant Updates
-------------------

SIMP Scenarios and simp_config_settings.yaml
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

We have changed the way that SIMP includes classes. There is a new top-level
variable, set in ``manifests/site.pp``, that controls the list of classes to be
included. The goal of this change is to ease users with existing infrastructures
into using full-bore SIMP.

Essentially, ``simp_classes.yaml`` has been replaced by ``scenarios/simp.yaml``
and ``simp_def.yaml`` has been replaced by ``simp_config_settings.yaml``.

API Changes
^^^^^^^^^^^

Quite a few modules have had changes that make them incompatible with the
Legacy SIMP stack.

We've attempted to capture those changes here at a high level so that you know
where you are going to need to focus to validate your Hiera data, ENC hooks,
and parameterized class calls.

Global catalysts
""""""""""""""""

SIMP Global catlysts now have a consitant naming scheme and are documented in
code in the ``simp_options`` module. In particular, we have changed not only the
value in hiera, but every module parameter that uses this value's name from
``client_nets`` to ``simp_options::trusted_nets``. Other changes were less
obtrusive, for example ``enable_selinux`` and other variations are now all
called ``simp_options::selinux``. Every Catayst is strongly typed and documented
in the module.

Strong Parameter Typing
"""""""""""""""""""""""

All SIMP provided modules should now be strong typed with `Puppet Data Types`_.

De-Verbing of Defines
"""""""""""""""""""""

Many of the defined types have been renamed to no longer be 'verb-oriented'.
The ``iptables`` module is probably the widest reaching change where the
standard 'ease-of-use' aliases have been moved under a ``listen`` namespace.

For instance, ``iptables::tcp_stateful_listen`` is now ``iptables::listen::tcp_stateful``

Additionally, any ``add_rule`` defines were changed to just ``rule``. For
example, ``auditd::add_rule`` was changed to just ``auditd::rule``.

Centralized Management of Application x509 PKI Certs
""""""""""""""""""""""""""""""""""""""""""""""""""""

In the past, application specific PKI certificates were copied into the application
space.  This varied per application and left certs strewn throughout the system.
Now, certificates for all SIMP-managed applications are copied from
``/etc/pki/simp/x509``, into a central location, ``/etc/pki/simp_apps/<application_name>/x509``.

The extent to which SIMP manages PKI is governed by two new catalysts, ``pki`` and
``pki::source``.  Additionally, every SIMP module which uses ``pki``
has been modified to use a common set of pki class parameters.  A high-level
description is given below, using simp_elasticsearch as an example.

# @param pki
#   * If 'simp', include SIMP's pki module and use pki::copy to manage
#     application certs in /etc/pki/simp_apps/simp_elasticsearch/x509
#   * If true, do *not* include SIMP's pki module, but still use pki::copy
#     to manage certs in /etc/pki/simp_apps/simp_elasticsearch/x509
#   * If false, do not include SIMP's pki module and do not use pki::copy
#     to manage certs.  You will need to appropriately assign a subset of:
#     * app_pki_dir
#     * app_pki_key
#     * app_pki_cert
#     * app_pki_ca
#     * app_pki_ca_dir
#
# @param app_pki_external_source
#   * If pki = 'simp' or true, this is the directory from which certs will be
#     copied, via pki::copy.  Defaults to /etc/pki/simp/x509.
#
#   * If pki = false, this variable has no effect.

Keydist
"""""""

Keydist has been relocated to a second module path to facilitate workign with
r10k. The new modulepath is located at ``/var/simp/environments/``, and the
default location of keydist is now
``/var/simp/environments/simp/site_files/pki_files/files/keydist/``

Forked modules
""""""""""""""

Most forked modules (modules that don't start with 'simp') have been updated to
latest upstream.

pupmod-simp-simpcat
"""""""""""""""""""

To deconflict with the upstream ``puppetlabs-concat`` module, the ``simpcat``
**functions** were renamed to be prefaced by ``simpcat`` instead of ``concat``.

A simple find and replace of ``concat_fragment`` and ``concat_build`` in legacy
code with ``simpcat_fragment`` and ``simpcat_build`` should suffice. Be sure to
check for ``Concat_fragment`` and ``Concat_build`` resource dependencies!

pupmod-simp-foreman
"""""""""""""""""""

The ``foreman`` module has been removed until Foreman works consistently with
Puppet 4.

pupmod-simp-ganglia
"""""""""""""""""""

The ``ganglia`` module has not yet been ported to Puppet 4 and therefore not
present in this release.

pupmod-simp-windowmanager
"""""""""""""""""""""""""

Rewritten and renamed module to pupmod-simp-gnome.

pupmod-simp-nscd
""""""""""""""""

The ``nscd`` module has been removed and the functionality replaced by ``sssd``.

pupmod-simp-openldap
""""""""""""""""""""

The ``openldap`` module has been renamed to ``simp_openldap`` to pave the way
towards using a more up-to-date implementation of the core openldap component
module from the community.

pupmod-simp-pam
"""""""""""""""

Generic, custom content can be specified to replace templated content by using
the $use_templates parameter.

pam::access:rule resources can be added through hiera using the
$pam::access::users hash.

pupmod-simp-simplib
"""""""""""""""""""

Removed all manifests and Puppet code from this module. It now only contains
functions and custom type aliases.

List of modules that were created or forked after removing content from simplib:

* pupmod-simp-at
* pupmod-simp-chkrootkit
* pupmod-simp-useradd
* pupmod-simp-swap
* pupmod-simp-cron
* pupmod-simp-resolv
* pupmod-simp-issue
* pupmod-simp-fips
* puppetlabs-motd
* trlinkin-nsswitch
* camptocamp-kmod
* puppetlabs-motd
* saz-timezone

The rest of the content was added to our profile module, simp-simp.

pupmod-simp-snmpd
"""""""""""""""""

The ``snmpd`` module has been removed until updates can be made available.

pupmod-simp-xwindows
""""""""""""""""""""

Module has been rewritten and renamed to pupmod-simp-gdm.

Puppet AIO
^^^^^^^^^^

The latest version of the Puppet AIO stack has been included, along with an
updated Puppet Server and PuppetDB.

simp-extras
^^^^^^^^^^^

The main ``simp`` RPM has been split to move the lesser-used portions of the
SIMP infrastructure into a ``simp-extras`` RPM. This RPM will grow as more of
the non-essential portions are identified and isolated.

The goal of this RPM is to keep the SIMP core version churn to a minimum while
allowing the ecosystem around the SIMP core to grow and flourish as time
progresses.

Security Announcements
----------------------

RPM Updates
-----------

+---------------------+-------------+-------------+
| Package             | Old Version | New Version |
+=====================+=============+=============+
| puppet-agent        | N/A         | 1.8.3-1     |
+---------------------+-------------+-------------+
| puppet-client-tools | N/A         | 1.1.0-1     |
+---------------------+-------------+-------------+
| puppetdb            | 2.3.8-1     | 4.3.0-1     |
+---------------------+-------------+-------------+
| puppetdb-termini    | N/A         | 4.3.0-1     |
+---------------------+-------------+-------------+
| puppetdb-terminus   | 2.3.8-1     | N/A         |
+---------------------+-------------+-------------+
| puppetserver        | 1.1.1-1     | 2.7.2-1     |
+---------------------+-------------+-------------+

Fixed Bugs
----------

New Features
------------

Known Bugs
----------

.. _file bugs: https://simp-project.atlassian.net
.. _Puppet Location Reference: https://docs.puppet.com/puppet/4.7/reference/whered_it_go.html#where-did-everything-go-in-puppet-4.x
.. _r10k: https://github.com/puppetlabs/r10k
.. _Puppet Code Manager: https://docs.puppet.com/pe/latest/code_mgr.html
.. _Puppet Data Types: https://docs.puppet.com/puppet/latest/lang_data_type.html
