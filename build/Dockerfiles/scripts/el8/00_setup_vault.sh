#!/bin/sh -e

VAULT="https://vault.almalinux.org/8.4"
GPG_KEY="file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux"

# Replace all default repo files with vault repos before any package installation.
# The almalinux:8.4 image ships only the original signing key; current AlmaLinux
# mirrors serve packages signed with a newer key that the base image cannot verify.
# Vault packages are still signed with the original key.
find /etc/yum.repos.d/ -name '*.repo' -delete

cat > /etc/yum.repos.d/almalinux-vault.repo << EOF
[baseos]
name=AlmaLinux 8.4 Vault - BaseOS
baseurl=${VAULT}/BaseOS/x86_64/os/
gpgkey=${GPG_KEY}
gpgcheck=1
enabled=1

[appstream]
name=AlmaLinux 8.4 Vault - AppStream
baseurl=${VAULT}/AppStream/x86_64/os/
gpgkey=${GPG_KEY}
gpgcheck=1
enabled=1

[powertools]
name=AlmaLinux 8.4 Vault - PowerTools
baseurl=${VAULT}/PowerTools/x86_64/os/
gpgkey=${GPG_KEY}
gpgcheck=1
enabled=1

[extras]
name=AlmaLinux 8.4 Vault - Extras
baseurl=${VAULT}/extras/x86_64/os/
gpgkey=${GPG_KEY}
gpgcheck=1
enabled=1
EOF
