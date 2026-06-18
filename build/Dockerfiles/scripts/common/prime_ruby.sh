#!/bin/bash
#
# Warm the build workspace: clone simp-core as build_user and run bundle
# install under the mise-managed Ruby so gems are cached in the image.
#
# Used by: ISO build images (SIMP_EL*_Build.dockerfile)
#
set -euo pipefail

user_id="${1:-build_user}"

# Check out a copy of simp-core for building
runuser "$user_id" -l -c "git clone https://github.com/simp/simp-core"

# Prep the build space (ruby/bundler are provided by mise; see mise.sh)
runuser "$user_id" -l -c "cd simp-core && bundle install"
