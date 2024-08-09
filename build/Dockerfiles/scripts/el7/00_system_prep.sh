#!/bin/sh -e

# System base package preparation

# Fix issues with overlayfs
yum clean all
rm -f /var/lib/rpm/__db*
yum clean all && yum history sync

# Deal with vault-ized CentOS7 repos, post-EOL
sed -i \
  -e 's@^mirrorlist.*=os$@baseurl=http://archive.kernel.org/centos-vault/centos/$releasever/os/$basearch/@' \
  -e 's@^mirrorlist.*=updates$@baseurl=http://archive.kernel.org/centos-vault/centos/$releasever/updates/$basearch/@' \
  -e 's@^mirrorlist.*=extras$@baseurl=http://archive.kernel.org/centos-vault/centos/$releasever/extras/$basearch/@' \
  -e 's@^mirrorlist.*=centosplus$@baseurl=http://archive.kernel.org/centos-vault/centos/$releasever/centosplus/$basearch/@' \
  -e 's@^mirrorlist.*=os$@baseurl=http://archive.kernel.org/centos-vault/centos/$releasever/os/$basearch/@' \
  /etc/yum.repos.d/CentOS-Base.repo

sed -i -e '/^#mirrorlist/d' -e '/^#baseurl=/d' /etc/yum.repos.d/{CentOS-Base.repo,CentOS-SCLo-scl-*.repo} ||:

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
