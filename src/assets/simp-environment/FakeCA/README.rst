These scripts can be used to act as a fake CA.

This CA should *NOT* be used in production unless you have no other
alternative.

Host Certificates
=================

Bulk Host Certificate Creation
------------------------------

Enter the hostnames of the certificates that you wish to create in the file
``togen``, one per line and run the ``gencerts_nopass.sh`` script.

If you wish to use alternate DNS names, separate the names with commas and no
spaces like the following example:

  primary.name,alt.name.1,alt.name.2,ip.addr.1,ip.addr.2

.. NOTE::

  If you specify ``auto`` as an option to the ``gencerts_nopass.sh`` script,
 then you will not be asked any questions and all default values will be used.

Command Line Host Certificate Creation
--------------------------------------

You can also create host certificates for single hosts at the command line.
This capability is generally meant for use by automated systems, but can also
be used to regenerate the keys for a single host.

.. NOTE::

  This capability only works in ``auto`` mode

Example:

  ./gencerts_nopass.sh auto primary.name,alt.name.1,alt.name.2,ip.addr.1,ip.addr.2


User Certificates
=================

To generate user certificates, add users to the ``usergen`` file in the following
format (one per line) and run the ``usergen.sh`` script.

   username  email-address

The output of usergen will be placed in ``output/users``.

Single users cannot be generated at the command line.


Certificate Output
==================

By default, all certificates will be placed at
``../site_files/pki_files/files/keydist``.

You can change this by setting the environment variable ``KEYDIST_DIR`` to your
preferred target directory before calling the script.

.. IMPORTANT::

  If you set ``KEYDIST_DIR``, the certificate is still registered for **this** CA!


Full Reset
==========

Run the ``clean.sh`` script to reset to a clean state.

.. WARNING::

  This will delete the *ENTIRE* CA and all previously signed certificates!
