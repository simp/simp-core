#!/bin/sh -e

user_id="${1:-build_user}"
ruby_version="${2:-2.7}"

# Set up RVM
runuser $user_id -l -c "echo 'gem: --no-document' > .gemrc"

# Do our best to get one of the keys from at one of the servers, and to
# trust the right ones if the GPG keyservers return bad keys
#
# This is the key that we want:
#
#  7D2BAF1CF37B13E2069D6956105BD0E739499BDB # piotr.kuczynski@gmail.com
#
# See:
#   - https://rvm.io/rvm/security
#   - https://github.com/rvm/rvm/blob/master/docs/gpg.md
#   - https://github.com/rvm/rvm/issues/4449
#   - https://github.com/rvm/rvm/issues/4250
#   - https://seclists.org/oss-sec/2018/q3/174
#
key_id='7D2BAF1CF37B13E2069D6956105BD0E739499BDB'
runuser $user_id -l -c "for i in {1..5}; do { gpg2 --keyserver hkp://keys.openpgp.org --recv-keys $key_id || gpg2 --keyserver hkp://keyserver.ubuntu.com --recv-keys $key_id; } && break || sleep 1; done"
#runuser $user_id -l -c "gpg2 --refresh-keys"
runuser $user_id -l -c "curl -sSL https://raw.githubusercontent.com/rvm/rvm/stable/binscripts/rvm-installer -o rvm-installer && curl -sSL https://raw.githubusercontent.com/rvm/rvm/stable/binscripts/rvm-installer.asc -o rvm-installer.asc && gpg2 --verify rvm-installer.asc rvm-installer && bash rvm-installer"
runuser $user_id -l -c "rvm install ${ruby_version}"
runuser $user_id -l -c "rvm use --default ${ruby_version}"
runuser $user_id -l -c "rvm all do gem install bundler -v '~> 1.16'"
runuser $user_id -l -c "rvm all do gem install bundler -v '~> 2.0'"
