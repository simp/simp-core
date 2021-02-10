#!/bin/bash

mkdir -p /etc/rpm
echo '%_install_langs C:en:en_US:en_US.UTF-8' > /etc/rpm/macros.image-language-conf

yum --noplugins \
    --setopt=override_install_langs=en_US.utf8 \
    --setopt=tsflags=nodocs \
    --setopt=install_weak_deps=False \
    install -y glibc-langpack-en 2>/dev/null ||:

# Ensure that the image stays minimal
cat << HERE > /etc/yum.conf
[main]
best=True
clean_requirements_on_remove=True
gpgcheck=1
install_weak_deps=False
installonly_limit=2
keepcache=False
multilib_policy=best
skip_if_unavailable=True
tsflags=nodocs
HERE
