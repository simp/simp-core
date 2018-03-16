SIMP 6.2.0-RC1
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
   releases. **Direct upgrades will not work!**

   At this point, do not expect any of our code moving forward to work with
   Puppet 3.

If you find any issues, please `file bugs`_!


Significant Updates
-------------------

Security Announcements
----------------------

RPM Updates
-----------

Removed Modules
---------------

pupmod-simp-mcollective and pupmod-simp-activemq
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
* Puppetlabs support for MCollective has been effectively dropped, rendering
  the SIMP modules to support this, ``pupmod-simp-mcollective`` and
  ``pupmod-simp-activemq``, non-functional.

Security Updates
----------------

Fixed Bugs
----------

New Features
------------

Known Bugs
----------

* There is a bug in ``Facter 3`` that causes it to segfault when printing large
  unsigned integers - `FACT-1732`_

  * This may cause your run to crash if you run ``puppet agent -t --debug``

* The ``krb5`` module may have issues in some cases, validation pending
* The graphical ``switch user`` functionality does not work. We are working
  with the vendor to discover a solution
* simp_options::selinux does not control if the simp selinux module is included
  when the simp scenario is used. The knockout prefix must also be used
  to remove it from the scenario maps.  - `SIMP-3858`_

.. _FACT-1732: https://tickets.puppetlabs.com/browse/FACT-1732
.. _SIMP-3858: https://simp-project.atlassian.net/browse/SIMP-3858
.. _file bugs: https://simp-project.atlassian.net
