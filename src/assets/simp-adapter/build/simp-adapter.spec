%define puppet_confdir /etc/puppetlabs/puppet

Summary: SIMP Adapter for the AIO Puppet Installation
Name: simp-adapter
Version: 0.0.2
Release: 0
License: Apache-2.0
Group: Applications/System
Source: %{name}-%{version}-%{release}.tar.gz
Buildroot: %{_tmppath}/%{name}-%{version}-%{release}-buildroot
Buildarch: noarch

Prefix: %{_sysconfdir}/simp

Requires: rsync
Requires(post): puppet
Requires(post): puppetserver
Requires(post): puppetdb
%{?el6:Requires(post): procps}
%{?el7:Requires(post): procps-ng}

Requires: puppet-agent < 2.0.0
Requires: puppet-agent >= 1.6.2
Requires: puppet-client-tools < 2.0.0
Requires: puppet-client-tools >= 1.1.0
Requires: puppetdb < 5.0.0
Requires: puppetdb >= 4.2.2
Requires: puppetdb-termini < 5.0.0
Requires: puppetdb-termini >= 4.2.2
Requires: puppetserver < 3.0.0
Requires: puppetserver >= 2.6.0
Provides: simp-adapter = %{version}
Provides: simp-adapter-foss = %{version}

%package pe
Summary: SIMP Adapter for the Puppet Enterprise Puppet Installation
License: Apache-2.0
Requires: rsync
Requires(post): puppet-agent
Requires(post): pe-puppetserver
Requires(post): pe-puppetdb
%{?el6:Requires(post): procps}
%{?el7:Requires(post): procps-ng}
Requires: puppet-agent < 2.0.0
Requires: puppet-agent >= 1.6.2
Requires: pe-client-tools >= 15.0.0
Requires: pe-puppetdb < 5.0.0
Requires: pe-puppetdb >= 4.2.2
Requires: pe-puppetdb-termini < 5.0.0
Requires: pe-puppetdb-termini >= 4.2.2
Requires: pe-puppetserver >= 2015.0.0
Provides: simp-adapter = %{version}

%description
An adapter RPM for gluing together a SIMP version with the AIO Puppet
installation.

%description pe
An adapter RPM for gluing together a SIMP version with the Puppet Enterprise
Puppet installation.

%prep
%setup -q

%build

%install
mkdir -p %{buildroot}%{prefix}
install -p -m 750 -D src/sbin/simp_rpm_helper %{buildroot}/usr/local/sbin/simp_rpm_helper
install -p -m 640 -D src/conf/adapter_config.yaml %{buildroot}%{prefix}/adapter_config.yaml

mkdir -p %{buildroot}%{puppet_confdir}
install -p -m 640 -D puppet_config/auth.conf %{buildroot}%{puppet_confdir}/auth.conf.simp
install -p -m 640 -D puppet_config/hiera.yaml %{buildroot}%{puppet_confdir}/hiera.yaml.simp

%clean
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
%config(noreplace) %{prefix}/adapter_config.yaml
/usr/local/sbin/simp_rpm_helper
%attr(-,-,puppet) %{puppet_confdir}/auth.conf.simp
%attr(-,-,puppet) %{puppet_confdir}/hiera.yaml.simp

%files pe
%defattr(-,root,root,-)
%config(noreplace) %{prefix}/adapter_config.yaml
/usr/local/sbin/simp_rpm_helper
%attr(-,-,puppet) %{puppet_confdir}/auth.conf.simp
%attr(-,-,puppet) %{puppet_confdir}/hiera.yaml.simp

%post
# Post installation stuff

if  [ $1 -eq 1 ]; then
  # If this is present, we're being installed via Kickstart and should set the
  # system to automatically install the packages into the correct location.

  if [ -f /anaconda-yum.yumtx ]; then
    echo 'copy_rpm_data : true' >> %{prefix}/adapter_config.yaml
  fi
fi

PATH=$PATH:/opt/puppetlabs/bin

# This is here due to a bug in the Puppet Server RPM that does not properly
# nail up the Puppet UID and GID to 52
#
# Unfortunately, we can't guarantee order in 'post', so we may have to munge up
# the filesystem pretty hard

puppet_uid=`id -u puppet 2>/dev/null`
puppet_gid=`id -g puppet 2>/dev/null`

restart_puppetserver=0

puppet_owned_dirs='/opt/puppetlabs /etc/puppetlabs /var/log'

if [ -n $puppet_gid ]; then
  if [ "$puppet_gid" != '52' ]; then

    if `pgrep -f puppetserver &>/dev/null`; then
      puppet resource service puppetserver stop || :
      wait
      restart_puppetserver=1
    fi

    groupmod -g 52 puppet || :

    for dir in $puppet_owned_dirs; do
      if [ -d $dir ]; then
        find $dir -gid $puppet_gid -exec chgrp puppet {} \;
      fi
    done
  fi
else
  # Add puppet group
  groupadd -r -g 52 puppet || :
fi

if [ -n $puppet_uid ]; then
  if [ "$puppet_uid" != '52' ]; then

    if `pgrep -f puppetserver &>/dev/null`; then
      puppet resource service puppetserver stop || :
      wait
      restart_puppetserver=1
    fi

    usermod -u 52 puppet || :

    for dir in $puppet_owned_dirs; do
      if [ -d $dir ]; then
        find $dir -uid $puppet_uid -exec chown puppet {} \;
      fi
    done
  fi
else
  # Add puppet user
  useradd -r --uid 52 --gid puppet --home /opt/puppetlabs/server/data/puppetserver --shell $(which nologin) --comment "puppetserver daemon" puppet || :
fi

if [ $restart_puppetserver -eq 1 ]; then
  puppet resource service puppetserver start
fi

# PuppetDB doesn't have a set user and group, but we really want to make sure
# that the directory permissions aren't awful

# Add puppet group
getent group puppetdb > /dev/null || groupadd -r puppetdb || :

# Add puppet user
getent passwd puppetdb > /dev/null || useradd -r --gid puppetdb --home /opt/puppetlabs/server/data/puppetdb --shell $(which nologin) --comment "puppetdb daemon" puppetdb || :


puppet config set trusted_node_data true || :
puppet config set digest_algorithm sha256 || :
puppet config set stringify_facts false || :

(
  cd %{puppet_confdir}

  simp_overrides='hiera.yaml auth.conf'
  for file in $simp_overrides; do

    if [ ! -f "${file}.simpbak" ] && [ ! -h $file ] && [ -f $file ]; then
      cat <<EOM > "${file}.simpbak"
### SIMP BACKUP ###
## This is a backup made of the ${file} that was present on the system prior
## to installing SIMP.
##
## Feel free to redirect the ${file} symlink to this file if you need to
## revert but be aware that some parts of the SIMP infrastructure may not
## function properly.

EOM

      cat $file >> "${file}.simpbak"
    fi

    ln -sf "${file}.simp" $file

    chgrp puppet $file
  done

  # Only do permission fixes on a fresh install
  if [ $1 -eq 1 ]; then
    # Fix the permissions laid down by the puppetserver and puppetdb RPMs
    for dir in code puppet puppetserver pxp-agent; do
      if [ -d $dir ]; then
        chmod -R u+rwX,g+rX,g-w,o-rwx $dir
        chmod ug+st $dir
        chgrp -R puppet $dir
      fi
    done

    if [ -d 'puppet/ssl' ]; then
      chmod -R u+rwX,g+rX,g-w,o-rwx 'puppet/ssl'
      chmod ug+st 'puppet/ssl'
      chown -R puppet:puppet 'puppet/ssl'
    fi

    if [ -d 'puppetdb' ]; then
      chmod -R u+rwX,g+rX,g-w,o-rwx 'puppetdb'
      chmod ug+st 'puppetdb'
      chgrp -R puppetdb 'puppetdb'
    fi
  fi
)

%postun
# Post uninstall stuff

(
  cd %{puppet_confdir}

  simp_overrides='hiera.yaml auth.conf'
  for file in $simp_overrides; do
    if [ -h $file ] && [ ! -e $file ]; then
      rm $file
    fi

    if [ ! -f ${file} ] && [ -f "${file}.simpbak" ]; then
      ln -sf "${file}.simp" $file
    fi
  done
)

%changelog
* Mon Sep 12 2016 Trevor Vaughan <tvaughan@onyxpoint.com> - 0.0.1-Alpha
  - First cut at the simp-adapter
