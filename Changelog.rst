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
  * RHEL 7.3 x86_64
  * CentOS 6.9 x86_64
  * CentOS 7.0 1611 x86_64

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

No breaking changes should be present in 6.1.0

RPM Installation
^^^^^^^^^^^^^^^^

FOSS SIMP
"""""""""

``sudo yum -y install simp-adapter simp``

Puppet Enterprise SIMP
""""""""""""""""""""""

``sudo yum -y install simp-adapter-pe simp``

Security Announcements
----------------------

RPM Updates
-----------

+---------------------+-------------+-------------+
| Package             | Old Version | New Version |
+=====================+=============+=============+
| puppet-agent        | N/A         | 1.8.3-1     |
+---------------------+-------------+-------------+
| puppet-client-tools | N/A         | 1.1.1-1     |
+---------------------+-------------+-------------+
| puppetdb            | 2.3.8-1     | 4.3.0-1     |
+---------------------+-------------+-------------+
| puppetdb-termini    | N/A         | 4.3.0-1     |
+---------------------+-------------+-------------+
| puppetdb-terminus   | 2.3.8-1     | N/A         |
+---------------------+-------------+-------------+
| puppetserver        | 1.1.1-1     | 2.7.2-1     |
+---------------------+-------------+-------------+

Removed Modules
---------------

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

.. _FACT-1732: https://tickets.puppetlabs.com/browse/FACT-1732
.. _Puppet Code Manager: https://docs.puppet.com/pe/latest/code_mgr.html
.. _Puppet Data Types: https://docs.puppet.com/puppet/latest/lang_data_type.html
.. _Puppet Location Reference: https://docs.puppet.com/puppet/4.7/reference/whered_it_go.html
.. _file bugs: https://simp-project.atlassian.net
.. _r10k: https://github.com/puppetlabs/r10k
