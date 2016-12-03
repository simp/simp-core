Summary: SIMP Environment Stub
Name: simp-environment
Version: 6.0.0
Release: Cupcake
License: Apache License, Version 2.0
Group: Applications/System
Buildroot: %{_tmppath}/%{name}-%{version}-%{release}-buildroot
Buildarch: noarch

Requires(pre,preun,post,postun): simp-adapter
Requires: simp-environment

Provides: simp-bootstrap = %{version}-%{release}

Prefix: /usr/share/simp/environments/simp

%description
Testing Stub for SIMP Environment installation

%prep

%build

%install
mkdir -p %{buildroot}%{prefix}
cat <<EOM > %{buildroot}%{prefix}/test_file
# Just testing stuff
EOM

%files
%defattr(-,root,root,-)
%{prefix}/test_file

%clean
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

%pre
/usr/local/sbin/simp_rpm_helper --rpm_dir=%{prefix} --rpm_section='pre' --rpm_status=$1 --preserve --target_dir='.'

%post
/usr/local/sbin/simp_rpm_helper --rpm_dir=%{prefix} --rpm_section='post' --rpm_status=$1 --preserve --target_dir='.'

%preun
/usr/local/sbin/simp_rpm_helper --rpm_dir=%{prefix} --rpm_section='preun' --rpm_status=$1 --preserve --target_dir='.'

%postun
/usr/local/sbin/simp_rpm_helper --rpm_dir=%{prefix} --rpm_section='postun' --rpm_status=$1 --preserve --target_dir='.'

%changelog
* Tue Sep 13 2016 Test Time <test_time@test.test> - 6.0.0-Cupcake
  -  Stubby McStubbins
