#!/bin/bash
#
# Install the baseline userland a Beaker test node (system under test) needs
# before acceptance tests run. Beaker installs the OpenVox/Puppet agent itself
# at test time, so this only provides the supporting utilities.
#
# Used by: Beaker SUT images (SIMP_EL*_Beaker.dockerfile)
#
# NOTE: redhat-lsb-core was intentionally dropped. It does not exist on EL9/EL10
# (LSB tooling was retired) and nothing in the SIMP acceptance stack needs it.
# Installs are no longer wrapped in "||:" so a missing package now fails the
# build instead of silently shipping an incomplete image.
#
set -euo pipefail

yum -y install \
  findutils \
  ncurses \
  openssl \
  procps-ng \
  rsync \
  sudo \
  systemd \
  tar
