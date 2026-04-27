#!/bin/sh -e

# Vault repos were set up by 00_setup_vault.sh. Downgrade any packages that
# minimize_package_installs.sh may have bumped above 9.0, keeping TLS-critical
# packages at their updated versions so network access stays working.
dnf downgrade -y --allowerasing --skip-broken \
  --exclude='ca-certificates' --exclude='*curl*' \
  --exclude='openssl*' --exclude='p11-kit*' \
  '*' ||:

dnf install -y sudo selinux-policy-targeted selinux-policy-devel policycoreutils policycoreutils-python-utils
