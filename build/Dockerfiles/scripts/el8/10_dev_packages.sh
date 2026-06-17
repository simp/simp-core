#!/bin/bash
#
# Install the full ISO/RPM build toolchain: rpmbuild tooling, ruby-devel and
# compilers, ISO-creation tools, fonts, an SSH server for CI, and helpers.
#
# Used by: ISO build images (SIMP_EL*_Build.dockerfile)
#
set -euo pipefail

dnf install -y epel-release
dnf config-manager --set-enabled powertools
dnf install -y rpm-build rpmdevtools rpm-devel rpm-sign yum-utils
dnf install -y ruby-devel
dnf install -y util-linux openssl augeas-libs createrepo genisoimage isomd5sum git gnupg2 libicu-devel libxml2 libxml2-devel libxslt libxslt-devel which
dnf install -y python3-virtualenv fontconfig dejavu-sans-fonts dejavu-sans-mono-fonts dejavu-serif-fonts dejavu-fonts-common libjpeg-devel zlib-devel openssl-devel
dnf install -y libyaml libyaml-devel glibc-headers autoconf gcc gcc-c++ glibc-devel readline-devel libffi-devel automake libtool bison sqlite-devel pinentry

# Helper packages
dnf install -y rubygems vim-enhanced jq

# SSH for CI testing
dnf install -y initscripts ||:
if [ -d /etc/ssh ]; then /bin/cp -a /etc/ssh /root; fi
dnf install -y openssh-server
if [ -d /root/ssh ]; then /bin/cp -a /root/ssh /etc && /bin/rm -rf /root/ssh; fi
