#!/bin/sh -e

# The oldest systemd doesn't work but new versions can skip this file
ln -sf /bin/true /usr/bin/systemctl
