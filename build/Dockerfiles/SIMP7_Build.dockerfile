# This version of CentOS is needed for the SELinux context builds
# After building, you will probably want to mount your ISO directory using
# something like the following:
#   * docker run -v $PWD/ISO:/ISO:Z -it <container ID>
#
# If you want to save your container for future use, you use use the `docker
# commit` command
#   * docker commit <running container ID> el7_build
#   * docker run -it el7_build
FROM centos:7.0.1406
ENV container docker

# Fix issues with overlayfs
RUN yum clean all
RUN rm -f /var/lib/rpm/__db*
RUN yum clean all
RUN yum install -y yum-plugin-ovl || :
RUN yum install -y yum-utils

# Prep for building against the oldest SELinux packages
RUN yum-config-manager --disable \*
RUN echo -e "[legacy]\nname=Legacy\nbaseurl=http://vault.centos.org/7.0.1406/os/x86_64\ngpgkey=https://www.centos.org/keys/RPM-GPG-KEY-CentOS-7\ngpgcheck=1" > /etc/yum.repos.d/legacy.repo
RUN cd /root; yum downgrade -y *

# Work around bug https://bugzilla.redhat.com/show_bug.cgi?id=1217477
# This does *not* update the SELinux packages, so it is safe
RUN yum --enablerepo=updates --enablerepo=base update -y git curl nss

RUN yum install -y sudo selinux-policy-targeted selinux-policy-devel policycoreutils policycoreutils-python

# Ensure that the 'build_user' can sudo to root for RVM
RUN echo 'Defaults:build_user !requiretty' >> /etc/sudoers
RUN echo 'build_user ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
RUN useradd -b /home -G wheel -m -c "Build User" -s /bin/bash -U build_user
RUN rm -rf /etc/security/limits.d/*.conf

# Install necessary packages
RUN yum-config-manager --enable extras
RUN yum install -y epel-release
RUN yum install -y openssl util-linux rpm-build augeas-devel createrepo genisoimage git gnupg2 libicu-devel libxml2 libxml2-devel libxslt libxslt-devel rpmdevtools which ruby-devel rpm-devel rpm-sign
RUN yum -y install centos-release-scl python-pip python-virtualenv fontconfig dejavu-sans-fonts dejavu-sans-mono-fonts dejavu-serif-fonts dejavu-fonts-common libjpeg-devel zlib-devel
RUN yum install -y libyaml-devel glibc-headers autoconf gcc gcc-c++ glibc-devel readline-devel libffi-devel openssl-devel automake libtool bison sqlite-devel
RUN yum-config-manager --enable rhel-server-rhscl-7-rpms
RUN yum --enablerepo=base -y install python27
RUN ln -sf /bin/true /usr/bin/systemctl

# Install helper packages
RUN yum install -y rubygems vim-enhanced jq

# Set up RVM
RUN runuser build_user -l -c "echo 'gem: --no-ri --no-rdoc' > .gemrc"
RUN runuser build_user -l -c "gpg2 --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3"
RUN runuser build_user -l -c "curl -sSL https://get.rvm.io | bash -s stable"
RUN runuser build_user -l -c "rvm install 2.1.9 --disable-binary"
RUN runuser build_user -l -c "rvm use --default 2.1.9"
RUN runuser build_user -l -c "rvm all do gem install bundler"
RUN runuser build_user -l -c "rvm use default; gem install simp-rake-helpers"
RUN runuser build_user -l -c "rvm use default; gem install json"
RUN runuser build_user -l -c "rvm use default; gem install charlock_holmes"
RUN runuser build_user -l -c "rvm use default; gem install posix-spawn"

# Check out a copy of simp-core for building
RUN runuser build_user -l -c "git clone https://github.com/simp/simp-core"

# Prep the build space
RUN runuser build_user -l -c "cd simp-core; bundle install"

# Drop into a shell for building
CMD /bin/bash -c "su -l build_user"
