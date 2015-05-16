# Generated from simp-cli-0.7.0.gem by gem2rpm -*- rpm-spec -*-
# vim: set syntax=eruby:
%global gemname simp-cli

%global gemdir /usr/local/share/gems
%global geminstdir %{gemdir}/gems/%{gemname}-%{version}
%global ruby_version 2.0

# gem2ruby's method of installing gems into mocked build roots will blow up
# unless this line is present:
%define _unpackaged_files_terminate_build 0

Summary: a cli interface to configure/manage SIMP
Name: rubygem-%{gemname}
Version: 1.0.0
Release: 0%{?dist}
Group: Development/Languages
License: Apache-2.0
URL: https://gforge.onyxpoint.net:8443/plugins/gitblit/summary/?r=SIMP.git
Source0: %{gemname}-%{version}.gem
# NOTE: in el6 this was ruby(abi):
Requires: ruby(runtime_executable) => %{ruby_version}
Requires: ruby(rubygems)
Requires: puppet => 3
Requires: rubygem-highline => 1.6.1
Requires: facter => 2.2
BuildRequires: ruby(runtime_executable) => %{ruby_version}
BuildRequires: ruby(rubygems)
BuildRequires: ruby
BuildArch: noarch
Provides: rubygem(%{gemname}) = %{version}

%description
simp-cli provides the 'simp' command to configure and manage SIMP.


%package doc
Summary: Documentation for %{name}
Group: Documentation
Requires: %{name} = %{version}-%{release}
BuildArch: noarch

%description doc
Documentation for %{name}


%prep
%setup -q -c -T
echo "======= %setup PWD: ${PWD}"
echo "======= %setup gemdir: %{gemdir}"
mkdir -p .%{gemdir}
mkdir -p .%{_bindir} # NOTE: this is needed for el7
gem install --local --install-dir .%{gemdir} \
            --bindir .%{_bindir} \
            --force %{SOURCE0}

%build

%install
mkdir -p %{buildroot}%{gemdir}
cp -pa .%{gemdir}/* \
        %{buildroot}%{gemdir}/

mkdir -p %{buildroot}%{_bindir}
cp -pa .%{_bindir}/* \
        %{buildroot}%{_bindir}/

find %{buildroot}%{geminstdir}/bin -type f | xargs chmod a+x

%files
%dir %{geminstdir}
%{_bindir}/simp
%{geminstdir}/bin
%{geminstdir}/lib
%exclude %{gemdir}/cache/%{gemname}-%{version}.gem
%{gemdir}/specifications/%{gemname}-%{version}.gemspec

%files doc
%doc %{gemdir}/doc/%{gemname}-%{version}


%changelog
* Fri Apr 24 2015 Nick Markowski <nmarkowski@keywcorp.com> - 1.0.0-0
- Use dist/, not pkg/, for built gems/rpms.  Added dist to the clean list.
- Determine el_version from mock chroot.
- Added pkg metadata to incorporate into build.

* Fri Mar 06 2015 Chris Tessmer <chris.tessmer@onyxpoint.com> - 1.0.0-0
- Initial package

