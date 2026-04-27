#!/bin/sh -e

VAULT="https://vault.almalinux.org/10.0"
GPG_KEY="file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux-10"

# Replace all default repo files with vault repos before any package installation.
# 10.0 is the oldest available AlmaLinux 10 release; this pins OS packages to that
# baseline for library compatibility with all 10.x systems.
find /etc/yum.repos.d/ -name '*.repo' -delete

cat > /etc/yum.repos.d/almalinux-vault.repo << EOF
[baseos]
name=AlmaLinux 10.0 Vault - BaseOS
baseurl=${VAULT}/BaseOS/x86_64/os/
gpgkey=${GPG_KEY}
gpgcheck=1
enabled=1

[appstream]
name=AlmaLinux 10.0 Vault - AppStream
baseurl=${VAULT}/AppStream/x86_64/os/
gpgkey=${GPG_KEY}
gpgcheck=1
enabled=1

[crb]
name=AlmaLinux 10.0 Vault - CRB
baseurl=${VAULT}/CRB/x86_64/os/
gpgkey=${GPG_KEY}
gpgcheck=1
enabled=1

[extras]
name=AlmaLinux 10.0 Vault - Extras
baseurl=${VAULT}/extras/x86_64/os/
gpgkey=${GPG_KEY}
gpgcheck=1
enabled=1
EOF
