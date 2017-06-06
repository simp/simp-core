%define puppet_confdir /etc/puppetlabs/puppet

Summary: SIMP Adapter for the AIO Puppet Installation
Name: simp-adapter
Version: 0.0.3
Release: 0%{?dist}
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
Provides: simp-adapter-pe = %{version}

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
install -p -m 640 -D puppet_config/hiera.yaml %{buildroot}%{puppet_confdir}/hiera.yaml.simp

%clean
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

%files
#
# TODO: Many of the hard-coded users and groups are likely to break when using
#       PE, which has different service, user, and group names:
#
#  - https://docs.puppet.com/pe/2016.4/install_what_and_where.html#user-accounts-installed
#  - https://docs.puppet.com/pe/2016.4/install_what_and_where.html#group-accounts-installed
#
%defattr(-,root,root,-)
%config(noreplace) %{prefix}/adapter_config.yaml
/usr/local/sbin/simp_rpm_helper
%attr(-,-,puppet) %{puppet_confdir}/hiera.yaml.simp

%files pe
%defattr(-,root,root,-)
%config(noreplace) %{prefix}/adapter_config.yaml
/usr/local/sbin/simp_rpm_helper
%attr(-,-,pe-puppet) %{puppet_confdir}/hiera.yaml.simp

%post
# Post installation stuff

if [ $1 -eq 1 ]; then
  # If the adapter is installed during a SIMP installation (e.g., from the ISO or
  # kickstarts), ensure that the /etc/simp/adapter_config.yaml is set up to copy over
  # the /usr
  #
  # This will only work if the kernel procinfo includes a `simp_install` argument
  simp_install=`awk -F "simp_install=" '{print $2}' /proc/cmdline | cut -f1 -d' '`
  if [ ! -z "${simp_install}" ]; then
    date=`date +%Y%m%d\ %H%M%S`
    [ -f %{prefix}/adapter_config.yaml ] || echo '---' > %{prefix}/adapter_config.yaml
    echo "# This file was modified by simp-adapter during a SIMP install" >> %{prefix}/adapter_config.yaml
    echo "# on ${date}:"            >> %{prefix}/adapter_config.yaml
    echo "target_directory: 'auto'" >> %{prefix}/adapter_config.yaml
    echo 'copy_rpm_data: true'     >> %{prefix}/adapter_config.yaml
  fi
fi

PATH=$PATH:/opt/puppetlabs/bin

id -u 'pe-puppet' &> /dev/null
if [ $? -eq 0 ]; then
  puppet_user='pe-puppet'
  puppet_group='pe-puppet'
  puppetdb_user='pe-puppetdb'
  puppetdb_group='pe-puppetdb'
else
  puppet_user='puppet'
  puppet_group='puppet'
  puppetdb_user='puppetdb'
  puppetdb_group='puppetdb'
fi

if [ "${puppet_user}" == 'puppet' ]; then
  # This fix is Puppet Open Source Only
  #
  # This is here due to a bug in the Puppet Server RPM that does not properly
  # nail up the Puppet UID and GID to 52
  #
  # Unfortunately, we can't guarantee order in 'post', so we may have to munge up
  # the filesystem pretty hard

  puppet_owned_dirs='/opt/puppetlabs /etc/puppetlabs /var/log/puppetlabs /var/run/puppetlabs'

  puppet_uid=`id -u puppet 2>/dev/null`
  puppet_gid=`id -g puppet 2>/dev/null`

  restart_puppetserver=0

  if [ -n $puppet_gid ]; then
    if [ "$puppet_gid" != '52' ]; then

      if `pgrep -f puppetserver &>/dev/null`; then
        puppet resource service puppetserver ensure=stopped || :
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
        puppet resource service puppetserver ensure=stopped  || :
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
    puppet resource service puppetserver ensure=running
  fi

  # PuppetDB doesn't have a set user and group, but we really want to make sure
  # that the directory permissions aren't awful

  # Add puppet group
  getent group puppetdb > /dev/null || groupadd -r puppetdb || :

  # Add puppet user
  getent passwd puppetdb > /dev/null || useradd -r --gid puppetdb --home /opt/puppetlabs/server/data/puppetdb --shell $(which nologin) --comment "puppetdb daemon" puppetdb || :
fi
# End Puppet Open Source permissions munging

puppet config set trusted_node_data true || :
puppet config set digest_algorithm sha256 || :
puppet config set stringify_facts false || :

(
  cd %{puppet_confdir}

  simp_overrides='hiera.yaml'
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

    chgrp $puppet_group $file
  done

  # Only do permission fixes on a fresh install
  if [ $1 -eq 1 ]; then
    # Fix the permissions laid down by the puppetserver and puppetdb RPMs
    for dir in code puppet puppetserver pxp-agent; do
      if [ -d $dir ]; then
        chmod -R u+rwX,g+rX,g-w,o-rwx $dir
        chmod ug+st $dir
        chgrp -R $puppet_group $dir
      fi
    done

    if [ -d 'puppet/ssl' ]; then
      chmod -R u+rwX,g+rX,g-w,o-rwx 'puppet/ssl'
      chmod ug+st 'puppet/ssl'
      chown -R ${puppet_user}:${puppet_group} 'puppet/ssl'
    fi

    if [ -d 'puppetdb' ]; then
      chmod -R u+rwX,g+rX,g-w,o-rwx 'puppetdb'
      chmod ug+st 'puppetdb'
      chgrp -R $puppetdb_group 'puppetdb'
    fi
  fi
)

%postun
# Post uninstall stuff

(
  cd %{puppet_confdir}

  simp_overrides='hiera.yaml'
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
* Wed May 22 2017 Nick Miller <nick.miller@onyxpoint.com> - 0.0.4-0
- Removed packaged auth.conf in favor of managing it with Puppet

* Wed Mar 08 2017 Trevor Vaughan <tvaughan@onyxpont.com> - 0.0.3-0
- Handle PE and Puppet Open source in the post section
- Add dist to the release field to account for RPM generation on EL6 vs EL7
- Updates to work better with PE and with the new method for detecting
  kickstart installs as added by Chris Tessmer <ctessmer@onyxpoint.com>

* Mon Mar 06 2017 Liz Nemsick <lnemsick.simp@gmail.com> -  0.0.3-0
- Fix 'puppet resource service' bugs in %post
- Add /var/run/puppetlabs to the list of directories to traverse,
  when fixing puppet uid/gid.
- Fix simp_rpm_helper bugs that prevented SIMP module RPM uninstalls
  in certain scenarios

* Mon Sep 12 2016 Trevor Vaughan <tvaughan@onyxpoint.com> - 0.0.1-Alpha
- First cut at the simp-adapter
