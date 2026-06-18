#!/bin/bash
#
# Install mise (Ruby version manager) system-wide on AlmaLinux 8 from the
# upstream rpm repo. The managed Rubies are provisioned later by mise.sh.
#
# Used by: ISO build images (SIMP_EL8_Build.dockerfile)
#
set -euo pipefail

dnf install -y dnf-plugins-core
dnf config-manager --add-repo https://mise.en.dev/rpm/mise.repo
dnf install -y mise
