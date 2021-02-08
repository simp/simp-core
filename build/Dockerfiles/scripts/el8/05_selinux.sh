#!/bin/sh -e

# Prep for building against the oldest SELinux packages
dnf config-manager --disable \*
echo -e "[legacy]\nname=Legacy\nbaseurl=https://vault.centos.org/8.0.1905/BaseOS/x86_64/os\ngpgkey=https://www.centos.org/keys/RPM-GPG-KEY-CentOS-8\ngpgcheck=1" > /etc/yum.repos.d/legacy.repo
echo -e "[legacy-extras]\nname=LegacyExtras\nbaseurl=https://vault.centos.org/8.0.1905/extras/x86_64/os\ngpgkey=https://www.centos.org/keys/RPM-GPG-KEY-CentOS-8\ngpgcheck=1" > /etc/yum.repos.d/legacy_extras.repo
echo -e "[legacy-AppStream]\nname=LegacyAppStream\nbaseurl=https://vault.centos.org/8.0.1905/AppStream/x86_64/os\ngpgkey=https://www.centos.org/keys/RPM-GPG-KEY-CentOS-8\ngpgcheck=1" > /etc/yum.repos.d/legacy_appstream.repo
echo -e "[legacy-PowerTools]\nname=LegacyPowerTools\nbaseurl=https://vault.centos.org/8.0.1905/extras/x86_64/os\ngpgkey=https://www.centos.org/keys/RPM-GPG-KEY-CentOS-8\ngpgcheck=1" > /etc/yum.repos.d/legacy_powertools.repo
echo -e "[legacy-centosplus]\nname=LegacyCentosPlus\nbaseurl=https://vault.centos.org/8.0.1905/extras/x86_64/os\ngpgkey=https://www.centos.org/keys/RPM-GPG-KEY-CentOS-8\ngpgcheck=1" > /etc/yum.repos.d/legacy_centosplus.repo

cd /root; yum downgrade --allowerasing -x 'glibc*' -x 'nss*' -x 'libnss*' -x nspr -y '*' || :

yum install -y sudo selinux-policy-targeted selinux-policy-devel policycoreutils policycoreutils-python-utils
