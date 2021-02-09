#!/bin/sh -e

# System base package preparation

# Fix issues with overlayfs
yum clean all
rm -f /var/lib/rpm/__db*
yum clean all && yum history sync

# The `yum-plugin-ovl` package is needed to avoid "copy-up" mistmatch
# issues problems when using overlayFS.  However, in early releases of
# EL7, the package was not included—so the `touch /var/lib/rpm/*;`
# workaround is needed to safely install `yum-plugin-ovl`.
#
# See:
#   - https://docs.docker.com/storage/storagedriver/overlayfs-driver/#limitations-on-overlayfs-compatibility
#
touch /var/lib/rpm/*; yum install -y yum-plugin-ovl || true
touch /var/lib/rpm/*; rpm -qi yum-utils || yum install -y yum-utils
