%define puppet_confdir /etc/puppetlabs/puppet

Summary: SIMP Adapter for the AIO Puppet Installation
Name: simp-adapter
Version: 0.0.1
Release: 0
License: Apache-2.0
Group: Applications/System
Source: %{name}-%{version}-%{release}.tar.gz
Buildroot: %{_tmppath}/%{name}-%{version}-%{release}-buildroot
Buildarch: noarch

Prefix: %{_sysconfdir}/simp

Requires: rsync
Requires(post): puppet
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

%package pe
Summary: SIMP Adapter for the Puppet Enterprise Puppet Installation
License: Apache-2.0
Requires: rsync
Requires(post): puppet
Requires: pe-puppet-agent < 2.0.0
Requires: pe-puppet-agent >= 1.6.2
Requires: pe-client-tools < 2.0.0
Requires: pe-client-tools >= 1.1.0
Requires: pe-puppetdb < 5.0.0
Requires: pe-puppetdb >= 4.2.2
Requires: pe-puppetdb-termini < 5.0.0
Requires: pe-puppetdb-termini >= 4.2.2
Requires: pe-puppetserver < 3.0.0
Requires: pe-puppetserver >= 2.6.0
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
%{puppet_confdir}/auth.conf.simp
%{puppet_confdir}/hiera.yaml.simp

%files pe
%defattr(-,root,root,-)
%config(noreplace) %{prefix}/adapter_config.yaml
/usr/local/sbin/simp_rpm_helper
%{puppet_confdir}/auth.conf.simp
%{puppet_confdir}/hiera.yaml.simp

%post
# Post installation stuff

PATH=$PATH:/opt/puppetlabs/bin

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
  done
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
