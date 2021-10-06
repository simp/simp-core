#!/bin/sh -e

# Prep for building against the oldest SELinux packages
yum-config-manager --disable \* >& /dev/null

# sslverify=0 is to acommodate the expired cross-signing CA (DST Root CA X3)
# and the  old R3 for Let's encrypt
#
# Normally this wouldn't be a problem, but since we start way back at 7.0.1406
# and work forward (to accumulate SELinux policies from the oldest packages),
# this causes curl to barf, even if we add the new chain.  We could remove the
# expired certs, but an intermediate update to the ca-certificates RPM will
# wipe that out after it runs `update-ca-trust`.
#
# Instead of dealing with all that, we're setting sslverify
# We are contemplating other solutions to the SELinux policy issue (like
# gathering the accumulated SELinux policies into an RPM once instead of
# building form scratch each time), but we won't be able to explore them until
# at least after 6.6.0.
echo -e "[legacy]\nname=Legacy\nbaseurl=https://vault.centos.org/7.0.1406/os/x86_64\ngpgkey=https://www.centos.org/keys/RPM-GPG-KEY-CentOS-7\ngpgcheck=1\nsslverify=0" > /etc/yum.repos.d/legacy.repo
cd /root; yum downgrade -x 'nss*' -x 'libnss*' -x nspr -y '*'

# Work around bug https://bugzilla.redhat.com/show_bug.cgi?id=1217477
# This does *not* update the SELinux packages, so it is safe
yum --enablerepo=updates --enablerepo=base update -y git curl nss binutils
yum install -y sudo selinux-policy-targeted selinux-policy-devel policycoreutils policycoreutils-python
