Summary: GPGKEYS
Name: simp-gpgkeys
Version: 2.0.0
Release: 0
License: Public Domain
Group: Applications/System
Source: %{name}-%{version}-%{release}.tar.gz
Buildroot: %{_tmppath}/%{name}-%{version}-%{release}-buildroot
Buildarch: noarch

Prefix: /srv/www/yum/SIMP

%description
A collection of GPG Keys Required for SIMP to function properly.

All keys copyright their respective owners.

%prep
%setup -q

%build

%install
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

# Make your directories here.
mkdir -p %{buildroot}/%{prefix}/GPGKEYS

#Now install the files.
cp RPM-GPG-KEY* %{buildroot}/%{prefix}/GPGKEYS

%clean
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

%files
%defattr(0644,root,root,0755)
%{prefix}/GPGKEYS

%post

%changelog
* Mon May 25 2015 Trevor Vaughan <tvaughan@onyxpoint.com> - 2.0.0-0
- Initial Public Release
