# This version of CentOS is needed for the SELinux context builds
# After building, you will probably want to mount your ISO directory using
# something like the following:
#   * docker run -v $PWD/ISO:/ISO:Z -it <container ID>
#
# If you want to save your container for future use, you use use the `docker
# commit` command
#   * docker commit <running container ID> el7_build
#   * docker run -it el7_build
#FROM centos:8
FROM centos:centos8.1.1911
ENV container docker

RUN dnf install -y --setopt=override_install_langs=en_US.utf8 --setopt=install_weak_deps=False --setopt=tsflags=nodocs 'dnf-command(config-manager)'
RUN dnf config-manager --save --setopt=best=True
RUN dnf config-manager --save --setopt=clean_requirements_on_remove=True
RUN dnf config-manager --save --setopt=gpgcheck=True
RUN dnf config-manager --save --setopt=install_weak_deps=False
RUN dnf config-manager --save --setopt=installonly_limit=2
RUN dnf config-manager --save --setopt=keepcache=False
RUN dnf config-manager --save --setopt=multilib_policy=best
RUN dnf config-manager --save --setopt=releasever='${releasever}'
RUN dnf config-manager --save --setopt=skip_if_unavailable=True
RUN dnf config-manager --save --setopt=overide_install_langs=en_US.utf8
RUN dnf config-manager --save --setopt=tsflags=nodocs

RUN yum -y install glibc-langpack-en

# Fix issues with overlayfs
RUN yum clean all
RUN rm -f /var/lib/rpm/__db*
RUN yum clean all
RUN yum install -y yum-plugin-ovl ||:
RUN yum install -y yum-utils

# Will probably need something like this later
# Prep for building against the oldest SELinux packages
RUN dnf config-manager --disable \*
RUN echo -e "[legacy]\nname=Legacy\nbaseurl=https://vault.centos.org/8.0.1905/BaseOS/x86_64/os\ngpgkey=https://www.centos.org/keys/RPM-GPG-KEY-CentOS-8\ngpgcheck=1" > /etc/yum.repos.d/legacy.repo
RUN echo -e "[legacy-extras]\nname=LegacyExtras\nbaseurl=https://vault.centos.org/8.0.1905/extras/x86_64/os\ngpgkey=https://www.centos.org/keys/RPM-GPG-KEY-CentOS-8\ngpgcheck=1" > /etc/yum.repos.d/legacy_extras.repo
RUN echo -e "[legacy-AppStream]\nname=LegacyAppStream\nbaseurl=https://vault.centos.org/8.0.1905/AppStream/x86_64/os\ngpgkey=https://www.centos.org/keys/RPM-GPG-KEY-CentOS-8\ngpgcheck=1" > /etc/yum.repos.d/legacy_appstream.repo
RUN echo -e "[legacy-PowerTools]\nname=LegacyPowerTools\nbaseurl=https://vault.centos.org/8.0.1905/extras/x86_64/os\ngpgkey=https://www.centos.org/keys/RPM-GPG-KEY-CentOS-8\ngpgcheck=1" > /etc/yum.repos.d/legacy_powertools.repo
RUN echo -e "[legacy-centosplus]\nname=LegacyCentosPlus\nbaseurl=https://vault.centos.org/8.0.1905/extras/x86_64/os\ngpgkey=https://www.centos.org/keys/RPM-GPG-KEY-CentOS-8\ngpgcheck=1" > /etc/yum.repos.d/legacy_centosplus.repo

RUN cd /root; yum downgrade --allowerasing -x 'glibc*' -x 'nss*' -x 'libnss*' -x nspr -y '*' || :

RUN yum install -y sudo selinux-policy-targeted selinux-policy-devel policycoreutils policycoreutils-python-utils

# Ensure that the 'build_user' can sudo to root for RVM
RUN echo 'Defaults:build_user !requiretty' >> /etc/sudoers
RUN echo 'build_user ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
RUN useradd -b /home -G wheel -m -c "Build User" -s /bin/bash -U build_user
RUN rm -rf /etc/security/limits.d/*.conf

# Install necessary packages
RUN yum install -y epel-release
RUN yum install -y rpm-build rpmdevtools ruby-devel rpm-devel rpm-sign
RUN yum install -y util-linux openssl augeas-libs createrepo genisoimage git gnupg2 libicu-devel libxml2 libxml2-devel libxslt libxslt-devel which ruby-devel
RUN yum -y install scl-utils python2-virtualenv python3-virtualenv fontconfig dejavu-sans-fonts dejavu-sans-mono-fonts dejavu-serif-fonts dejavu-fonts-common libjpeg-devel zlib-devel openssl-devel
RUN yum install -y libyaml glibc-headers autoconf gcc gcc-c++ glibc-devel readline-devel libffi-devel automake libtool bison sqlite-devel
RUN ln -sf /bin/true /usr/bin/systemctl

# Install helper packages
RUN yum install -y rubygems vim-enhanced jq

# Install SSH for CI testing
RUN yum -y install initscripts
RUN if [ -d /etc/ssh ]; then /bin/cp -a /etc/ssh /root; fi
RUN yum -y install openssh-server
RUN if [ -d /root/ssh ]; then /bin/cp -a /root/ssh /etc && /bin/rm -rf /root/ssh; fi

# Set up RVM
RUN runuser build_user -l -c "echo 'gem: --no-document' > .gemrc"

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
RUN runuser build_user -l -c "for i in {1..5}; do { gpg2 --keyserver  hkp://pool.sks-keyservers.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 || gpg2 --keyserver hkp://pgp.mit.edu --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 || gpg2 --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3; } && break || sleep 1; done"
RUN runuser build_user -l -c "for i in {1..5}; do { gpg2 --keyserver  hkp://pool.sks-keyservers.net --recv-keys 7D2BAF1CF37B13E2069D6956105BD0E739499BDB || gpg2 --keyserver hkp://pgp.mit.edu --recv-keys 7D2BAF1CF37B13E2069D6956105BD0E739499BDB || gpg2 --keyserver hkp://keys.gnupg.net --recv-keys 7D2BAF1CF37B13E2069D6956105BD0E739499BDB; } && break || sleep 1; done"
#RUN runuser build_user -l -c "gpg2 --refresh-keys"
RUN runuser build_user -l -c "curl -sSL https://raw.githubusercontent.com/rvm/rvm/stable/binscripts/rvm-installer -o rvm-installer && curl -sSL https://raw.githubusercontent.com/rvm/rvm/stable/binscripts/rvm-installer.asc -o rvm-installer.asc && gpg2 --verify rvm-installer.asc rvm-installer && bash rvm-installer"
RUN runuser build_user -l -c "rvm install 2.6"
RUN runuser build_user -l -c "rvm use --default 2.6"
RUN runuser build_user -l -c "rvm all do gem install bundler -v '~> 1.16'"
RUN runuser build_user -l -c "rvm all do gem install bundler -v '~> 2.0'"

# Check out a copy of simp-core for building
RUN runuser build_user -l -c "git clone https://github.com/simp/simp-core"

# Prep the build space
RUN runuser build_user -l -c "cd simp-core; bundle install"

# Drop into a shell for building
CMD /bin/bash -c "su -l build_user"
