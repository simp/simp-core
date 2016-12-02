Summary: SIMP Stub
Name: simp
Version: 6.0.0
Release: Muffin
License: Apache License, Version 2.0
Group: Applications/System
Buildroot: %{_tmppath}/%{name}-%{version}-%{release}-buildroot
Buildarch: noarch
Requires: createrepo
Requires: lsb
Requires: httpd >= 2.2

Requires: simp-adapter

Requires: simp-environment

Obsoletes: simp-hiera < 3.0.2

Prefix: %{_sysconfdir}/puppet

%description
Testing Stub for SIMP

%prep

%build

%install
mkdir -p %{buildroot}%{_sysconfdir}/simp
echo "%{version}-%{release}" > %{buildroot}%{_sysconfdir}/simp/simp.version
chmod u=rwX,g=rX,o=rX -R %{buildroot}%{_sysconfdir}/simp

%clean
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
%{_sysconfdir}/simp/simp.version

%post

%postun

%changelog
* Tue Sep 13 2016 Test Time <test_time@test.test> - 6.0.0-Cupcake
  -  Stubby McStubbins
