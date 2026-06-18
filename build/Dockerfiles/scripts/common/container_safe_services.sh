#!/bin/bash
#
# Install a systemd path+oneshot unit that strips CapabilityBoundingSet and
# PrivateNetwork directives from unit files. Those directives fail inside an
# unprivileged container and cannot be reliably overridden, so this keeps the
# systemd-based test node bootable.
#
# Used by: Beaker SUT images (SIMP_EL*_Beaker.dockerfile)
#
set -euo pipefail

if [ -d "/usr/lib/systemd" ]; then
  mkdir -p "/usr/lib/systemd/system"

  # Services that try to set capabilities will not work inside of a container and
  # overrides don't appear to work
  cat << HERE > "/usr/lib/systemd/system/container_safe_services.path"
[Install]
WantedBy=multi-user.target

[Unit]
Wants=container_safe_services.service

[Path]
PathChanged=/usr/lib/systemd/system/
HERE

  cat << HERE > "/usr/lib/systemd/system/container_safe_services.service"
[Unit]
Description=Keep services container safe
DefaultDependencies=no

[Service]
Type=oneshot
ExecStart=/usr/bin/sh -c "/usr/bin/sed -i '/CapabilityBoundingSet/d' /usr/lib/systemd/system/*.service"
ExecStart=/usr/bin/sh -c "/usr/bin/sed -i '/PrivateNetwork/d' /usr/lib/systemd/system/*.service"
ExecStart=/usr/bin/systemctl daemon-reload
HERE
fi

# daemon-reload needs a running systemd, which is absent during the image build;
# ignore failure here. The unit is still enabled so it runs when the node boots.
systemctl daemon-reload || true
systemctl enable container_safe_services.path
