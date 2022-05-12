#!/bin/sh -e

sed -i -e 's@^mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=\([^&/=$]*\).*@baseurl=http://vault.centos.org/centos/$releasever/\1/$basearch/os/@g' /etc/yum.repos.d/CentOS-Linux-*.repo
dnf clean all
dnf makecache

dnf install -y --setopt=override_install_langs=en_US.utf8 --setopt=install_weak_deps=False --setopt=tsflags=nodocs 'dnf-command(config-manager)'
dnf config-manager --save --setopt=best=True
dnf config-manager --save --setopt=clean_requirements_on_remove=True
dnf config-manager --save --setopt=gpgcheck=True
dnf config-manager --save --setopt=install_weak_deps=False
dnf config-manager --save --setopt=installonly_limit=2
dnf config-manager --save --setopt=keepcache=False
dnf config-manager --save --setopt=multilib_policy=best
dnf config-manager --save --setopt=releasever='${releasever}'
dnf config-manager --save --setopt=skip_if_unavailable=True
dnf config-manager --save --setopt=overide_install_langs=en_US.utf8
dnf config-manager --save --setopt=tsflags=nodocs

yum -y install glibc-langpack-en

# Fix issues with overlayfs
yum clean all
rm -f /var/lib/rpm/__db*
yum clean all
yum install -y yum-plugin-ovl ||:
yum install -y yum-utils
