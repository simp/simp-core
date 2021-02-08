#!/bin/sh -e

user_id="$1"

if [ -z "$user_id" ]; then
  user_id='build_user'
fi

useradd -b /home -G wheel -m -c "Build User" -s /bin/bash -U $user_id

# Ensure that '$user_id' can sudo to root for RVM
echo 'Defaults:$user_id !requiretty' >> /etc/sudoers
echo '$user_id ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
rm -rf /etc/security/limits.d/*.conf
