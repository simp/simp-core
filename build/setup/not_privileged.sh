# Install RVM, ruby 2.1.9, and bundler
gpg2 --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
curl -sSL https://get.rvm.io | bash -s stable --ruby=2.1.9
source ~/.rvm/scripts/rvm
rvm use --default 2.1.9
rvm all do gem install bundler

# Checkout SIMP Version
cd /vagrant/
git checkout tags/6.1.0-0

# Run bundler and download SIMP tar as the vagrant user
bundle install

# Run build:auto. For env defintions go to http://simp.readthedocs.io/en/master/getting_started_guide/ISO_Build/Building_SIMP_From_Tarball.html
yes | SIMP_BUILD_docs=no SIMP_ENV_NO_SELINUX_DEPS=yes BEAKER_destroy=no bundle exec rake build:auto[/vagrant/,6.X]
