#!/bin/sh -e

user_id="$1"

if [ -z "$user_id" ]; then
  user_id='build_user'
fi

# Check out a copy of simp-core for building
runuser $user_id -l -c "git clone https://github.com/simp/simp-core"

# Prep the build space
runuser $user_id -l -c "cd simp-core; bundle install"
