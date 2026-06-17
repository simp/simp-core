#!/bin/bash
#
# Configure dnf/yum for a minimal image footprint (no docs, no weak deps, a
# single language pack) and refresh the TLS trust + curl so the build can reach
# current package mirrors.
#
# Used by: both image families (Beaker SUT and ISO build)
#
set -euo pipefail

mkdir -p /etc/rpm
echo '%_install_langs C:en:en_US:en_US.UTF-8' > /etc/rpm/macros.image-language-conf

# Best-effort: the langpack may already be present or unavailable in vault repos.
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

# Needed for updated YUM servers
yum -y update ca-certificates curl
