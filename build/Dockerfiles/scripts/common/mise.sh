#!/bin/bash
#
# Provision Ruby for build_user with mise (https://mise.jdx.dev). mise itself is
# installed system-wide by the per-EL install_mise.sh; this installs the Ruby
# versions SIMP/OpenVox builds need and wires mise into build_user's shell.
#
#   Ruby 3.2 -> OpenVox 8 (current)
#   Ruby 4.0 -> OpenVox 9 (upcoming)
#
# Both Rubies are installed and kept available; the build arg selects the global
# default (see the SIMP_EL*_Build.dockerfile "ruby_version" ARG).
#
# Used by: ISO build images (SIMP_EL*_Build.dockerfile)
#
set -euo pipefail

user_id="${1:-build_user}"
default_ruby="${2:-3.2}"

# Both supported Rubies are always installed; the build arg only selects which
# one is the global default. Reject anything else so a typo can't silently ship
# an image missing a Ruby the build expects.
case "$default_ruby" in
  3.2|4.0) ;;
  *)
    echo "ERROR: unsupported ruby_version '${default_ruby}' (expected 3.2 or 4.0)" >&2
    exit 1
    ;;
esac

# Rubies to make available in the image. The default is listed first so mise
# treats it as the global default.
if [ "$default_ruby" = "4.0" ]; then
  ruby_list="ruby@4.0 ruby@3.2"
else
  ruby_list="ruby@3.2 ruby@4.0"
fi

# Don't ship gem docs.
runuser "$user_id" -l -c "echo 'gem: --no-document' > ~/.gemrc"

# Activate mise for both non-login (shims on PATH, used by runuser -l -c) and
# interactive login shells (the container CMD runs 'su -l build_user').
runuser "$user_id" -l -c 'echo '\''export PATH="$HOME/.local/share/mise/shims:$PATH"'\'' >> ~/.bash_profile'
runuser "$user_id" -l -c 'echo '\''eval "$(mise activate bash)"'\'' >> ~/.bashrc'

# Install the Rubies and set the global default (first entry in the list).
runuser "$user_id" -l -c "mise use -g ${ruby_list}"

# Install bundler for every Ruby mise manages. simp-rake-helpers requires
# bundler < 3.0, so pin to the 2.x release simp-core's Gemfile.lock is bundled
# with rather than taking the latest (currently 4.x).
bundler_version='2.7.2'
runuser "$user_id" -l -c "mise exec ruby@3.2 -- gem install bundler -v ${bundler_version}"
runuser "$user_id" -l -c "mise exec ruby@4.0 -- gem install bundler -v ${bundler_version}"

runuser "$user_id" -l -c "mise ls"
