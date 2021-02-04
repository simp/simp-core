#!/bin/sh -e

# Install necessary packages
yum install -y epel-release
yum install -y rpm-build rpmdevtools ruby-devel rpm-devel rpm-sign
yum install -y util-linux openssl augeas-libs createrepo genisoimage git gnupg2 libicu-devel libxml2 libxml2-devel libxslt libxslt-devel which ruby-devel
yum -y install scl-utils python2-virtualenv python3-virtualenv fontconfig dejavu-sans-fonts dejavu-sans-mono-fonts dejavu-serif-fonts dejavu-fonts-common libjpeg-devel zlib-devel openssl-devel
yum install -y libyaml glibc-headers autoconf gcc gcc-c++ glibc-devel readline-devel libffi-devel automake libtool bison sqlite-devel pinentry

# Install helper packages
yum install -y rubygems vim-enhanced jq

# Install SSH for CI testing
yum -y install initscripts
if [ -d /etc/ssh ]; then /bin/cp -a /etc/ssh /root; fi
yum -y install openssh-server
if [ -d /root/ssh ]; then /bin/cp -a /root/ssh /etc && /bin/rm -rf /root/ssh; fi
