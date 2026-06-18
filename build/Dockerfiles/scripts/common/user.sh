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

# Ensure that "$user_id" can sudo to root for the build tooling. Write a
# dedicated /etc/sudoers.d/ drop-in (idempotent across rebuilds) with the
# 0440 perms sudo requires, and validate it with visudo before it takes effect
# so a malformed line can't break sudo for the whole image.
sudoers_file="/etc/sudoers.d/${user_id}"
cat > "$sudoers_file" <<EOF
Defaults:${user_id} !requiretty
${user_id} ALL=(ALL) NOPASSWD: ALL
EOF
chmod 0440 "$sudoers_file"
visudo -cf "$sudoers_file"

rm -rf /etc/security/limits.d/*.conf
