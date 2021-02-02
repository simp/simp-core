#!/bin/sh -e

# Prep for building against the oldest SELinux packages
yum-config-manager --disable \* >& /dev/null
echo -e "[legacy]\nname=Legacy\nbaseurl=https://vault.centos.org/7.0.1406/os/x86_64\ngpgkey=https://www.centos.org/keys/RPM-GPG-KEY-CentOS-7\ngpgcheck=1" > /etc/yum.repos.d/legacy.repo
cd /root; yum downgrade -x 'nss*' -x 'libnss*' -x nspr -y '*'

# Work around bug https://bugzilla.redhat.com/show_bug.cgi?id=1217477
# This does *not* update the SELinux packages, so it is safe
yum --enablerepo=updates --enablerepo=base update -y git curl nss binutils
yum install -y sudo selinux-policy-targeted selinux-policy-devel policycoreutils policycoreutils-python
