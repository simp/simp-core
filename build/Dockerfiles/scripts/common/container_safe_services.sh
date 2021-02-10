#!/bin/bash

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

systemctl daemon-reload
systemctl enable container_safe_services.path
