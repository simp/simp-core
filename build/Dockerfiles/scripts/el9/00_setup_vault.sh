#!/bin/sh -e

VAULT="https://vault.almalinux.org/9.0"
GPG_KEY="file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux-9"

# Replace all default repo files with vault repos before any package installation.
# This pins all OS packages to 9.0 for library compatibility; packages built
# against 9.0 libraries will run on any later 9.x release.
find /etc/yum.repos.d/ -name '*.repo' -delete

cat > /etc/yum.repos.d/almalinux-vault.repo << EOF
[baseos]
name=AlmaLinux 9.0 Vault - BaseOS
baseurl=${VAULT}/BaseOS/x86_64/os/
gpgkey=${GPG_KEY}
gpgcheck=1
enabled=1

[appstream]
name=AlmaLinux 9.0 Vault - AppStream
baseurl=${VAULT}/AppStream/x86_64/os/
gpgkey=${GPG_KEY}
gpgcheck=1
enabled=1

[crb]
name=AlmaLinux 9.0 Vault - CRB
baseurl=${VAULT}/CRB/x86_64/os/
gpgkey=${GPG_KEY}
gpgcheck=1
enabled=1

[extras]
name=AlmaLinux 9.0 Vault - Extras
baseurl=${VAULT}/extras/x86_64/os/
gpgkey=${GPG_KEY}
gpgcheck=1
enabled=1
EOF
