#!/bin/sh -e

dnf config-manager --set-enabled crb
dnf install -y sudo selinux-policy-targeted selinux-policy-devel policycoreutils policycoreutils-python-utils
