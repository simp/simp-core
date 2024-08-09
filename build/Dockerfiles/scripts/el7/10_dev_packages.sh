#!/bin/sh -e

# Install necessary packages
yum-config-manager --enable extras

yum install -y acl ||:
yum install -y epel-release

yum install -y openssl util-linux augeas-devel genisoimage isomd5sum git gnupg2 libicu-devel libxml2 libxml2-devel libxslt libxslt-devel which ruby-devel
yum install -y rpm-build rpmdevtools rpm-devel rpm-sign yum-utils createrepo

yum install -y centos-release-scl python-pip python-virtualenv fontconfig dejavu-sans-fonts dejavu-sans-mono-fonts dejavu-serif-fonts dejavu-fonts-common libjpeg-devel zlib-devel openssl-devel

# Deal with vault-ized CentOS7 repos, post-EOL
# (at this point, SSL is updated enough use modern https)
yum-config-manager --setopt=base.baseurl='https://vault.centos.org/centos/$releasever/os/$basearch/' --save
yum-config-manager --setopt=updates.baseurl='https://vault.centos.org/centos/$releasever/updates/$basearch/' --save
yum-config-manager --setopt=extras.baseurl='https://vault.centos.org/centos/$releasever/extras/$basearch/' --save
yum-config-manager --setopt=centosplus.baseurl='https://vault.centos.org/centos/$releasever/centosplus/$basearch/' --save
yum-config-manager --setopt=centos-sclo-rh.baseurl='https://vault.centos.org/centos/$releasever/sclo/$basearch/rh/' --save
yum-config-manager --setopt=centos-sclo-sclo.baseurl='https://vault.centos.org/centos/$releasever/sclo/$basearch/sclo/' --save

sed -i -e 's/^mirrorlist/#\0/g' -e '/^#baseurl=/d' /etc/yum.repos.d/{CentOS-Base.repo,CentOS-SCLo-scl-rh.repo,CentOS-SCLo-scl.repo}

yum install -y libyaml-devel glibc-headers autoconf gcc gcc-c++ glibc-devel readline-devel libffi-devel automake libtool bison sqlite-devel

yum-config-manager --enable rhel-server-rhscl-7-rpms
yum --enablerepo=base -y install rh-python36

# Install helper packages
yum install -y rubygems vim-enhanced jq

# Install SSH for CI testing
if [ -d /etc/ssh ]; then /bin/cp -a /etc/ssh /root; fi
yum -y install openssh-server
if [ -d /root/ssh ]; then /bin/cp -a /root/ssh /etc && /bin/rm -rf /root/ssh; fi
