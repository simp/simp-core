#!/bin/bash
#
# Create the unprivileged build account (build_user) used to build SIMP ISOs.
# The account is a passwordless-sudo wheel member so the build tooling (mise,
# Ruby, rpmbuild) can manage system state during the build.
#
# Used by: ISO build images (SIMP_EL*_Build.dockerfile)
#
set -euo pipefail

user_id="${1:-build_user}"

useradd -b /home -G wheel -m -c "Build User" -s /bin/bash -U "$user_id"

# Ensure that "$user_id" can sudo to root for the build tooling.
# NOTE: these use double quotes so "$user_id" expands; the previous single-quoted
# versions wrote a literal "$user_id" into /etc/sudoers.
echo "Defaults:${user_id} !requiretty" >> /etc/sudoers
echo "${user_id} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
rm -rf /etc/security/limits.d/*.conf
