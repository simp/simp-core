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

Requires: simp
Requires: rsync
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

%package pe
Summary: SIMP Adapter for the Puppet Enterprise Puppet Installation
License: Apache-2.0
Requires: simp
Requires: rsync
Requires: pe-puppet-agent < 2.0.0
Requires: pe-puppet-agent >= 1.6.2
Requires: pe-puppet-client-tools < 2.0.0
Requires: pe-puppet-client-tools >= 1.1.0
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

%clean
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
%config(noreplace) %{prefix}/adapter_config.yaml
/usr/local/sbin/simp_rpm_helper

%files pe
%defattr(-,root,root,-)
%config(noreplace) %{prefix}/adapter_config.yaml
/usr/local/sbin/simp_rpm_helper

%post
# Post installation stuff

%postun
# Post uninstall stuff

%changelog
* Mon Sep 12 2016 Trevor Vaughan <tvaughan@onyxpoint.com> - 0.0.1-Alpha
  - First cut at the simp-adapter
