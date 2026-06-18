#!/bin/bash
#
# Install mise (Ruby version manager) system-wide on AlmaLinux 10 from COPR.
# The managed Rubies are provisioned later by mise.sh.
#
# Used by: ISO build images (SIMP_EL10_Build.dockerfile)
#
set -euo pipefail

dnf install -y 'dnf-command(copr)'
dnf copr enable -y jdxcode/mise
dnf install -y mise
