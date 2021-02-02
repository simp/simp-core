#!/bin/sh -e

user_id="$1"

if [ -z "$user_id" ]; then
  user_id='build_user'
fi

# Set up RVM
runuser $user_id -l -c "echo 'gem: --no-document' > .gemrc"

# Do our best to get one of the keys from at one of the servers, and to
# trust the right ones if the GPG keyservers return bad keys
#
# These are the keys we want:
#
#  409B6B1796C275462A1703113804BB82D39DC0E3 # mpapis@gmail.com
#  7D2BAF1CF37B13E2069D6956105BD0E739499BDB # piotr.kuczynski@gmail.com
#
# See:
#   - https://rvm.io/rvm/security
#   - https://github.com/rvm/rvm/blob/master/docs/gpg.md
#   - https://github.com/rvm/rvm/issues/4449
#   - https://github.com/rvm/rvm/issues/4250
#   - https://seclists.org/oss-sec/2018/q3/174
#
# NOTE (mostly to self): In addition to RVM's documented procedures,
# importing from https://keybase.io/mpapis may be a practical
# alternative for 409B6B1796C275462A1703113804BB82D39DC0E3:
#
#    curl https://keybase.io/mpapis/pgp_keys.asc | gpg2 --import
#
runuser $user_id -l -c "for i in {1..5}; do { gpg2 --keyserver  hkp://pool.sks-keyservers.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 || gpg2 --keyserver hkp://pgp.mit.edu --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 || gpg2 --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3; } && break || sleep 1; done"
runuser $user_id -l -c "for i in {1..5}; do { gpg2 --keyserver  hkp://pool.sks-keyservers.net --recv-keys 7D2BAF1CF37B13E2069D6956105BD0E739499BDB || gpg2 --keyserver hkp://pgp.mit.edu --recv-keys 7D2BAF1CF37B13E2069D6956105BD0E739499BDB || gpg2 --keyserver hkp://keys.gnupg.net --recv-keys 7D2BAF1CF37B13E2069D6956105BD0E739499BDB; } && break || sleep 1; done"
#runuser $user_id -l -c "gpg2 --refresh-keys"
runuser $user_id -l -c "curl -sSL https://raw.githubusercontent.com/rvm/rvm/stable/binscripts/rvm-installer -o rvm-installer && curl -sSL https://raw.githubusercontent.com/rvm/rvm/stable/binscripts/rvm-installer.asc -o rvm-installer.asc && gpg2 --verify rvm-installer.asc rvm-installer && bash rvm-installer"
runuser $user_id -l -c "rvm install 2.6"
runuser $user_id -l -c "rvm use --default 2.6"
runuser $user_id -l -c "rvm all do gem install bundler -v '~> 1.16'"
runuser $user_id -l -c "rvm all do gem install bundler -v '~> 2.0'"
