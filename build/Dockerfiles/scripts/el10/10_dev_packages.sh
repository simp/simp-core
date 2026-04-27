#!/bin/sh -e

dnf install -y epel-release ||:
dnf config-manager --set-enabled crb
dnf install -y rpm-build rpmdevtools rpm-devel rpm-sign yum-utils
dnf install -y ruby-devel
dnf install -y util-linux openssl augeas-libs createrepo_c git gnupg2 libicu-devel libxml2 libxml2-devel libxslt libxslt-devel which procps-ng
# genisoimage may not yet be in EPEL 10; xorriso is the modern alternative
dnf install -y genisoimage isomd5sum ||:
dnf install -y xorriso
dnf install -y python3 fontconfig libjpeg-devel zlib-devel openssl-devel
dnf install -y libyaml libyaml-devel autoconf gcc gcc-c++ glibc-devel readline-devel libffi-devel automake libtool bison sqlite-devel pinentry

# Helper packages
dnf install -y rubygems vim-enhanced jq

# SSH for CI testing; initscripts not available on EL10
if [ -d /etc/ssh ]; then /bin/cp -a /etc/ssh /root; fi
dnf install -y openssh-server
if [ -d /root/ssh ]; then /bin/cp -a /root/ssh /etc && /bin/rm -rf /root/ssh; fi
