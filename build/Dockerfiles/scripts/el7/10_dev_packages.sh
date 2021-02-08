#!/bin/sh -e

# Install necessary packages
yum-config-manager --enable extras

yum install -y acl ||:
yum install -y epel-release

yum install -y openssl util-linux rpm-build augeas-devel createrepo genisoimage git gnupg2 libicu-devel libxml2 libxml2-devel libxslt libxslt-devel rpmdevtools which ruby-devel rpm-devel rpm-sign

yum -y install centos-release-scl python-pip python-virtualenv fontconfig dejavu-sans-fonts dejavu-sans-mono-fonts dejavu-serif-fonts dejavu-fonts-common libjpeg-devel zlib-devel openssl-devel

yum install -y libyaml-devel glibc-headers autoconf gcc gcc-c++ glibc-devel readline-devel libffi-devel automake libtool bison sqlite-devel

yum-config-manager --enable rhel-server-rhscl-7-rpms
yum --enablerepo=base -y install python27

# Install helper packages
yum install -y rubygems vim-enhanced jq

# Install SSH for CI testing
if [ -d /etc/ssh ]; then /bin/cp -a /etc/ssh /root; fi
yum -y install openssh-server
if [ -d /root/ssh ]; then /bin/cp -a /root/ssh /etc && /bin/rm -rf /root/ssh; fi
