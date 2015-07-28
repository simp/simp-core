Summary: GPGKEYS
Name: simp-gpgkeys
Version: 2.0.0
Release: 2%{?dist}
License: Public Domain
Group: Applications/System
Source: %{name}-%{version}-1.tar.gz
Buildroot: %{_tmppath}/%{name}-%{version}-%{release}-buildroot
Buildarch: noarch

Prefix: %{_datadir}/simp/GPGKEYS

%description
A collection of GPG Keys Required for SIMP to function properly.

All keys copyright their respective owners.

%prep
%setup -q

%build

%install
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

# Make your directories here.
mkdir -p %{buildroot}/%{_sysconfdir}/pki/rpm-gpg
mkdir -p %{buildroot}/%{prefix}

#Now install the files.
cp RPM-GPG-KEY* %{buildroot}/%{_sysconfdir}/pki/rpm-gpg
cp RPM-GPG-KEY* %{buildroot}/%{prefix}

%clean
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

%files
%defattr(0644,root,root,0755)
%{_sysconfdir}/pki/rpm-gpg
%{prefix}

%post
#!/bin/bash

# If we're a SIMP server, place the keys into the appropriate web directory

for dir in '/srv/www/yum/SIMP' '/var/www/yum/SIMP'; do
  if [ -d $dir ]; then
    mkdir -p -m 0755 "${dir}/GPGKEYS"
  fi
  cp %{prefix}/RPM-GPG-KEY* "${dir}/GPGKEYS"

  # Get rid of any files that are present that aren't in the new directory.
  # Ensure that we don't have issues with operations in progress.
  old_key_list=`mktemp --suffix=.simp_gpgkeys`
  new_key_list=`mktemp --suffix=.simp_gpgkeys`

  ls "${dir}/GPGKEYS/RPM-GPG-KEY"* > $old_key_list
  ls "%{prefix}/RPM-GPG-KEY"* > $new_key_list

  for file in `A comm -23 $old_key_list $new_key_list`; do
    if [ -f "${dir}/GPGKEYS/${file}" ]; then
      rm -f "${dir}/GPGKEYS/${file}"
    fi
  done

  if [ -f $old_key_list ]; then
    rm -f $old_key_list
  fi

  if [ -f $new_key_list ]; then
    rm -f $new_key_list
  fi
done

%postun
#!/bin/bash

for dir in '/srv/www/yum/SIMP' '/var/www/yum/SIMP'; do
  if [ -d "${dir}/GPGKEYS" ]; then
    find -P "${dir}/GPGKEYS" -xdev -xautofs -delete
  fi
done

%changelog
* Tue Jul 28 2015 Trevor Vaughan <tvaughan@onyxpoint.com> - 2.0.0-2
- Now install the GPG keys to /usr/share/simp/GPGKEYS and /etc/pki/rpm-gpg
- Copy the keys into the SIMP default web dirs if they exist and be sure to
  clean up after ourselves in the future.

* Sat Jun 27 2015 Trevor Vaughan <tvaughan@onyxpoint.com> - 2.0.0-1
- Added the OS version to differentiate between the versions.

* Mon May 25 2015 Trevor Vaughan <tvaughan@onyxpoint.com> - 2.0.0-0
- Initial Public Release
