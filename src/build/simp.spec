Summary: SIMP Full Install
Name: simp
Version: 6.0.0
Release: 0%{?snapshot_release}
License: Apache License, Version 2.0
Group: Applications/System

Buildroot: %{_tmppath}/%{name}-%{version}-%{release}-buildroot
Buildarch: noarch
Requires: createrepo
Requires: lsb
Requires: simp-adapter
Requires: httpd >= 2.2
Obsoletes: simp-hiera < 3.0.2

# Core SIMP Requirements
Requires: pupmod-camptocamp-kmod >= 2.1.0, pupmod-camptocamp-kmod < 3.0.0
Requires: pupmod-herculesteam-augeasproviders >= 2.1.3-2016, pupmod-herculesteam-augeasproviders < 3.0.0
Requires: pupmod-herculesteam-augeasproviders_apache >= 2.0.1-2016, pupmod-herculesteam-augeasproviders_apache < 3.0.0
Requires: pupmod-herculesteam-augeasproviders_base >= 2.0.1-2016, pupmod-herculesteam-augeasproviders_base < 3.0.0
Requires: pupmod-herculesteam-augeasproviders_core >= 2.1.1-2016, pupmod-herculesteam-augeasproviders_core < 3.0.0
Requires: pupmod-herculesteam-augeasproviders_grub >= 2.3.1-2016, pupmod-herculesteam-augeasproviders_grub < 3.0.0
Requires: pupmod-herculesteam-augeasproviders_postgresql >= 2.0.3-2016, pupmod-herculesteam-augeasproviders_postgresql < 3.0.0
Requires: pupmod-herculesteam-augeasproviders_puppet >= 2.0.2-2016, pupmod-herculesteam-augeasproviders_puppet < 3.0.0
Requires: pupmod-herculesteam-augeasproviders_shellvar >= 2.1.1-2016, pupmod-herculesteam-augeasproviders_shellvar < 3.0.0
Requires: pupmod-herculesteam-augeasproviders_ssh >= 2.5.0-2016, pupmod-herculesteam-augeasproviders_ssh < 3.0.0
Requires: pupmod-herculesteam-augeasproviders_sysctl >= 2.1.0-2016, pupmod-herculesteam-augeasproviders_sysctl < 3.0.0
Requires: pupmod-onyxpoint-gpasswd >= 1.0.0-2016, pupmod-onyxpoint-gpasswd < 2.0.0
Requires: pupmod-puppetlabs-apache >= 1.10.0-2016, pupmod-puppetlabs-apache < 2.0.0
Requires: pupmod-puppetlabs-concat >= 2.2.0-2016, pupmod-puppetlabs-concat < 3.0.0
Requires: pupmod-puppetlabs-inifile >= 1.6.0-2016, pupmod-puppetlabs-inifile < 2.0.0
Requires: pupmod-puppetlabs-java >= 1.2.0-2016, pupmod-puppetlabs-java < 2.0.0
Requires: pupmod-puppetlabs-java_ks >= 1.4.0-2016, pupmod-puppetlabs-java_ks < 2.0.0
Requires: pupmod-puppetlabs-motd >= 1.4.0-2016, pupmod-puppetlabs-motd < 2.0.0
Requires: pupmod-puppetlabs-postgresql >= 4.8.0, pupmod-puppetlabs-postgresql < 5.0.0
Requires: pupmod-puppetlabs-puppetdb >= 5.0.0-2016, pupmod-puppetlabs-puppetdb < 6.0.0
Requires: pupmod-puppetlabs-stdlib >= 4.13.1-2016, pupmod-puppetlabs-stdlib < 5.0.0
Requires: pupmod-richardc-datacat >= 0.6.2-2016, pupmod-richardc-datacat < 1.0.0
Requires: pupmod-saz-timezone >= 3.3.0, pupmod-saz-timezone < 4.0.0
Requires: pupmod-simp-acpid >= 1.0.1-2016, pupmod-simp-acpid < 2.0.0
Requires: pupmod-simp-activemq >= 4.0.0-2016, pupmod-simp-activemq < 5.0.0
Requires: pupmod-simp-aide >= 6.0.0-2016, pupmod-simp-aide < 7.0.0
Requires: pupmod-simp-at >= 0.0.1-2016, pupmod-simp-at < 1.0.0
Requires: pupmod-simp-auditd >= 7.0.0-2016, pupmod-simp-auditd < 8.0.0
Requires: pupmod-simp-autofs >= 6.0.0, pupmod-simp-autofs < 7.0.0
Requires: pupmod-simp-chkrootkit >= 0.0.1, pupmod-simp-chkrootkit < 1.0.0
Requires: pupmod-simp-clamav >= 6.0.0-2016, pupmod-simp-clamav < 7.0.0
Requires: pupmod-simp-compliance_markup >= 2.0.0, pupmod-simp-compliance_markup < 3.0.0
Requires: pupmod-simp-cron >= 0.0.1, pupmod-simp-cron < 1.0.0
Requires: pupmod-simp-dhcp >= 6.0.0-2016, pupmod-simp-dhcp < 7.0.0
Requires: pupmod-simp-fips >= 0.1.0, pupmod-simp-fips < 1.0.0
Requires: pupmod-simp-freeradius >= 7.0.0-2016, pupmod-simp-freeradius < 8.0.0
Requires: pupmod-simp-issue >= 0.0.1, pupmod-simp-issue < 1.0.0
Requires: pupmod-simp-ganglia >= 6.0.0, pupmod-simp-ganglia < 7.0.0
Requires: pupmod-simp-haveged >= 0.3.2-2016, pupmod-simp-haveged < 1.0.0
Requires: pupmod-simp-incron >= 0.0.1, pupmod-simp-incron < 1.0.0
Requires: pupmod-simp-iptables >= 6.0.0, pupmod-simp-iptables < 7.0.0
Requires: pupmod-simp-krb5 >= 7.0.0-2016, pupmod-simp-krb5 < 8.0.0
Requires: pupmod-simp-logrotate >= 6.0.0-2016, pupmod-simp-logrotate < 7.0.0
Requires: pupmod-simp-mcollective >= 3.0.0-2016, pupmod-simp-mcollective < 4.0.0
Requires: pupmod-simp-named >= 6.0.0, pupmod-simp-named < 7.0.0
Requires: pupmod-simp-network >= 6.0.0, pupmod-simp-network < 7.0.0
Requires: pupmod-simp-nfs >= 6.0.0, pupmod-simp-nfs < 7.0.0
Requires: pupmod-simp-ntpd >= 6.0.0, pupmod-simp-ntpd < 7.0.0
Requires: pupmod-simp-oddjob >= 2.0.0-2016, pupmod-simp-oddjob < 3.0.0
Requires: pupmod-simp-openldap >= 6.0.0, pupmod-simp-openldap < 7.0.0
Requires: pupmod-simp-pam >= 6.0.0, pupmod-simp-pam < 7.0.0
Requires: pupmod-simp-pki >= 6.0.0, pupmod-simp-pki < 7.0.0
Requires: pupmod-simp-postfix >= 5.0.1, pupmod-simp-postfix < 6.0.0
Requires: pupmod-simp-pupmod >= 7.1.0, pupmod-simp-pupmod < 8.0.0
Requires: pupmod-simp-resolv >= 0.0.1, pupmod-simp-resolv < 1.0.0
Requires: pupmod-simp-rsync >= 6.0.0, pupmod-simp-rsync < 7.0.0
Requires: pupmod-simp-rsyslog >= 7.0.0, pupmod-simp-rsyslog < 8.0.0
Requires: pupmod-simp-selinux >= 2.0.1-2016, pupmod-simp-selinux < 3.0.0
Requires: pupmod-simp-simp >= 3.0.0, pupmod-simp-simp < 4.0.0
Requires: pupmod-simp-simp_apache >= 6.0.0, pupmod-simp-simp_apache < 7.0.0
Requires: pupmod-simp-simpcat >= 6.0.0, pupmod-simp-simpcat < 7.0.0
Requires: pupmod-simp-simplib >= 3.1.0, pupmod-simp-simplib < 4.0.0
Requires: pupmod-simp-site >= 2.0.2-2016, pupmod-simp-site < 3.0.0
Requires: pupmod-simp-snmpd >= 6.0.0, pupmod-simp-snmpd < 7.0.0
Requires: pupmod-simp-ssh >= 6.0.0, pupmod-simp-ssh < 7.0.0
Requires: pupmod-simp-sssd >= 6.0.0, pupmod-simp-sssd < 7.0.0
Requires: pupmod-simp-stunnel >= 6.0.0, pupmod-simp-stunnel < 7.0.0
Requires: pupmod-simp-sudo >= 5.0.1, pupmod-simp-sudo < 6.0.0
Requires: pupmod-simp-sudosh >= 6.0.0-2016, pupmod-simp-sudosh < 7.0.0
Requires: pupmod-simp-svckill >= 3.1.0, pupmod-simp-svckill < 4.0.0
Requires: pupmod-simp-swap >= 0.1.0, pupmod-simp-swap < 1.0.0
Requires: pupmod-simp-tcpwrappers >= 6.0.0, pupmod-simp-tcpwrappers < 7.0.0
Requires: pupmod-simp-tftpboot >= 6.0.0-2016, pupmod-simp-tftpboot < 7.0.0
Requires: pupmod-simp-tpm >= 1.0.0-2016, pupmod-simp-tpm < 2.0.0
Requires: pupmod-simp-tuned >= 0.0.1-2016, pupmod-simp-tuned < 1.0.0
Requires: pupmod-simp-upstart >= 6.0.0-2016, pupmod-simp-upstart < 7.0.0
Requires: pupmod-simp-useradd >= 0.0.1-2016, pupmod-simp-upstart < 1.0.0
Requires: pupmod-simp-xinetd >= 4.0.0-2016, pupmod-simp-xinetd < 5.0.0
Requires: pupmod-trlinkin-nsswitch >= 2.0.0, pupmod-trlinkin-nsswitch < 2.0.0
Requires: rubygem-simp-cli >= 1.0.24-0, rubygem-simp-cli < 2.0.0
Requires: rubygem-simp-cli-doc >= 1.0.24-0, rubygem-simp-cli-doc < 2.0.0
Requires: simp-adapter >= 0.0.2-0, simp-adapter < 1.0.0
Requires: simp-environment >= 6.0.0, simp-environment < 7.0.0
Requires: simp-gpgkeys >= 2.0.0-4%{?dist}, simp-gpgkeys < 3.0.0
Requires: simp-rsync >= 6.0.0-0, simp-rsync < 6.0.0
Requires: simp-rsync-clamav >= 5.1.0-3, simp-rsync-clamav < 6.0.0
Requires: simp-utils >= 6.0.0, simp-utils < 7.0.0

Prefix: %{_sysconfdir}/puppet

# SIMP Extras
%package extras
Summary: Extra Packages for SIMP
License: Apache-2.0
Requires: pupmod-bfraser-grafana >= 2.5.0-2016
Requires: pupmod-elasticsearch-elasticsearch >= 0.11.0-2016
Requires: pupmod-elasticsearch-logstash >= 0.6.4-2016
Requires: pupmod-electrical-file_concat >= 1.0.1-2016
Requires: pupmod-herculesteam-augeasproviders_mounttab >= 2.0.1-2016
Requires: pupmod-herculesteam-augeasproviders_nagios >= 2.0.1-2016
Requires: pupmod-herculesteam-augeasproviders_pam >= 2.0.3-2016
Requires: pupmod-puppetlabs-mysql >= 2.2.3-2016
Requires: pupmod-simp-foreman >= 1.0.0
Requires: pupmod-simp-gdm >= 6.0.0-2016
Requires: pupmod-simp-gnome >= 6.0.0-2016
Requires: pupmod-simp-jenkins >= 6.0.0-2016
Requires: pupmod-simp-libreswan >= 3.0.0-2016
Requires: pupmod-simp-libvirt >= 5.0.1-2016
Requires: pupmod-simp-mcafee >= 6.0.0-2016
Requires: pupmod-simp-mozilla >= 5.0.0-2016
Requires: pupmod-simp-openscap >= 6.0.0-2016
Requires: pupmod-simp-polkit >= 6.0.0-2016
Requires: pupmod-simp-simp_elasticsearch >= 4.0.0
Requires: pupmod-simp-simp_grafana >= 1.0.1-2016
Requires: pupmod-simp-simp_logstash >= 3.0.1-2016
Requires: pupmod-simp-vnc >= 6.0.0-2016
Requires: pupmod-simp-vsftpd >= 7.0.0-2016

%description
Stub for installing everything needed for a full SIMP system

%description extras
Stub for installing all 'extra' packages that are enhancements to SIMP but not
part of the supported core.

Unlike the main 'simp' require packages. Packages required by this RPM do not
have an upper bound to restrict breaking changes on a given distribution.

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
# Post installation stuff

if [ -f %{prefix}/autosign.conf ]; then
  chmod 644 %{prefix}/autosign.conf;
fi

if [ -f /etc/puppetlabs/puppet/autosign.conf ]; then
  chmod 644 %{prefix}/autosign.conf;
fi

if [ -f '%{_usr}/local/sbin/hiera_upgrade' ]; then
  %{_usr}/local/sbin/hiera_upgrade || true
fi

if [ -x '%{_usr}/local/sbin/puppetserver_clear_environment_cache' ]; then
  %{_usr}/local/sbin/puppetserver_clear_environment_cache
fi

if [ -x '%{_usr}/local/sbin/puppetserver_reload' ]; then
  %{_usr}/local/sbin/puppetserver_reload
fi

rpm_link_target="%{_var}/www/yum/`facter operatingsystem`/`facter operatingsystemmajrelease`"
rpm_link="%{_var}/www/yum/`facter operatingsystem`/`facter operatingsystemrelease`"
rpm_dir="$rpm_link/`facter hardwaremodel`/Updates"

umask 022;
if [ ! -d $rpm_dir ]; then
  mkdir -p $rpm_dir;
  cd $rpm_dir;

  createrepo .;

  ln -sf $rpm_link $rpm_link_target;
fi

%postun
# Post uninstall stuff

%changelog
* Tue Jan 10 2017 Jeanne Greulich <jeanne.greulich@onyxpoint.com> - 6.0.0
- Updated required version of simp modules

* Tue Oct 25 2016 Nick Miller <nick.miller@onyxpoint.com> - 6.0.0-Alpha
- Added i_version mount option to non-/var and non-/tmp partitions for IMA
    measuring

* Mon Sep 12 2016 Trevor Vaughan <tvaughan@onyxpoint.com> - 6.0.0-Alpha
- Alpha work for the 6.0.0 release
  - Restructuring the RPM build sequence

* Tue Sep 06 2016 Trevor Vaughan <tvaughan@onyxpoint.com> - 5.2.0-0
- Release of 5.2.0-0
  - Numerous bug fixes and enhancements, see the Changelog
  - This *is* a breaking change, but centered around non-core modules,
    particularly NFS

* Sat Mar 26 2016 Trevor Vaughan <tvaughan@onyxpoint.com> - 5.1.0-3
- Release 5.1.0-3

* Fri Dec 04 2015 Trevor Vaughan <tvaughan@onyxpoint.com> - 5.1.0-2
- Update to properly include the dependencies in the main simp RPM

* Fri Dec 04 2015 Trevor Vaughan <tvaughan@onyxpoint.com> - 5.1.0-1
- Included missing documentation updates
- Fixed the simp-bootstrap version update which missed the common -> simplib
  transition.

* Thu Nov 26 2015 Trevor Vaughan <tvaughan@onyxpoint.com> - 5.1.0-0
- Upgraded to Hiera 3 from Puppet Labs
- Incorporated a migration script for updating from the old simp-hiera
- Replaced facter calls to 'lsb*' with 'operatingsystem*' in the 'post' section
  of the RPM

* Tue Sep 29 2015 Trevor Vaughan <tvaughan@onyxpoint.com> - 5.1.0-RC1
- Bump for RC1
- FIPS mode now fully active out of the box!

* Tue Apr 28 2015 Nick Markowski <nmarkowski@kewycorp.com> - 5.1.0-Beta
- Incorporated new simp-config! Deleted old simp config. Pkg rake task
  now accepts multiple spec files in build/; will determine which spec
  file to use based on chroot.  Pkg.rake will now add all rpms built
  by a spec file to autorequires, not just one of them.

* Tue Mar 26 2015 Jacob Gingrich <jgingrich@onyxpoint.com> - 5.1.0-Beta
- Updated to facter 2.4.

* Tue Feb 17 2015 Trevor Vaughan <tvaughan@onyxpoint.com> - 5.1.0-Alpha
- Now enforce a reasonable password policy immediately after build from the DVD
- Changed puppet-server requirement to puppetserver for the new Clojure-based
  Puppet server.
- Added migration scripts to assist in the upgrade of an existing system to the
  new version support Puppet environments.
- See the Changelog for critical documentation on upgrading your system.

* Mon Dec 15 2014 Trevor Vaughan <tvaughan@onyxpoint.com> - 5.0.0-2
- Updated to pin facter below 2.3.0 until we can fix all
  integer/string issues.
- Removed all RPMs that were causing conflicts.
- Fixed the apache module race condition that was not allowing puppet
  to compile on systems without apache already installed.
- Verified module functionality for the ELK stack.

* Fri Dec 05 2014 Trevor Vaughan <tvaughan@onyxpoint.com> - 5.0.0-1
- Update to the first release of 5.0.0 patching several bugs
- Updated changelog in regards to GUI and %{_var}/tmp noexec issues
- Added patches for POODLE and Shellshock
- Added GPG keys for RHEL/EPEL/CentOS 7
- Fixed the puppet cron job
- Changed 'splay' to false by default for puppet clients

* Tue Nov 25 2014 Trevor Vaughan <tvaughan@onyxpoint.com> - 5.0.0-0
- Final release of 5.0.0
- There are still some issues to be worked out but most capabilities should
  work properly.
- NOTE: You *must* update to the latest system patches in order to get XWindows
  to work.

* Fri Oct 31 2014 Trevor Vaughan <tvaughan@onyxpoint.com> - 5.0.0-RC1
- First release candidate of 5.0.0.
- Releases now only include modules that have been verified to work.

* Mon Jul 21 2014 Trevor Vaughan <tvaughan@onyxpoint.com> - 5.0.0-Beta
- Updated to use %{_var} instead of /srv for most data.

* Fri Jun 27 2014 Trevor Vaughan <tvaughan@onyxpoint.com> - 5.0.0-Alpha
- Added a dependency on the new passenger-service package and removed the
  individual dependencies that that package can handle.
- Incorporating work from John Kellems <jkellems@keywcorp.com> into
  the 5.0/4.1 merge.

* Wed Apr 23 2014 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.1.0-Beta
- Well, we changed all the stuff..
- Doc updates coming in RC1
- Facter 2 was added

* Thu Apr 03 2014 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.1.0-Alpha3
- Third alpha of the 4.1 Series
- More class conversions and bug fixes ported from 4.0.6-1.

* Thu Dec 05 2013 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.1.0-Alpha2
- Second alpha of the 4.1 Series
- Major Additions
  - Puppet 3
  - Hiera (required)
  - Shinken
  - MCollective

* Fri Nov 22 2013 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.0.6-RC1
- Major changes:
  - Svckill has been ported to a native type
  - Support for OpenStack Grizzly from RDO has been added
  - Beta support for Shinken has been added
  - Support for audispd has been added
  - IPTables was updated to be a great deal more flexible
  - The Passenger temp directory was moved for security reasons
  - Split out the simp-mit and simp-doc RPMs

* Tue Sep 24 2013 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.0.5-1
- Major changes:
  - Added ability to not automaticaly restart the network
  - Updated to use new passenger temp directory of %{_var}/run/passenger.
  - Updated rsync to default to contimeout instead of I/O timeout.

* Thu Sep 12 2013 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.0.5-0
- Added support for LogStash, ElasticSearch, and Kibana 3 with
  reasonable security defaults.
- Fixed a critical bug in the iptables::add_all_listen define
- More closely comply with the 'tmp' directory settings of the SSG
- Added support for SELinux
- Removed support for akeys and replaced it with openssh-ldap
- Added kickstart support for OpenStack user-data scripts
- Updated Puppet to handle CVE-2013-3567

* Tue Apr 09 2013 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.0.4-2
- This release corrects some documentation omissions from the last release.
- Additionally, the code in the %post section checking for running instances of
  passenger was corrected. This means that the httpd service should always
  properly restart.

* Thu Mar 21 2013 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.0.4-1
- The last release had errors in the permissions on the rsync facl
  file. This release corrects that mistake.

* Tue Mar 12 2013 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.0.4-0
- Added support for RHEL/CentOS 6.4
- Updated BackupPC to fix CVE-2011-5081
- Updated Puppet to handle CVEs:
    - CVE-2013-1640
    - CVE-2013-1652
    - CVE-2013-1653
    - CVE-2013-1654
    - CVE-2013-1655
    - CVE-2013-2275

* Tue Mar 05 2013 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.0.3-0
- Fixed a security relevant bug with Apache settings
- Added CGroups support
- Added beta OpenStack support
- See Changelog for more details

* Tue Jan 15 2013 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.0.3-RC1
- Updated with passenger 3 update support. Added a kludge to the pre
  and post sections to try and get passenger working on upgrade
  without manual intervention.

* Mon Oct 08 2012 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.0.2-1
- Signed the last batch of RPMs with the wrong key!

* Tue Sep 25 2012 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.0.2-0
- Final cut for 4.0.2

* Mon Aug 20 2012 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.0.2-RC2
- Rollup for RC2.
- The documentation has been completely revamped and is now available
  as a PDF at the top level of the DVD.

* Tue Jul 10 2012 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.0.2-RC1
- Updated many of the base external packages to their latest versions:
  - BackupPC-3.1.0-13
  - augeas-libs-0.10.0-3
  - clamav-0.97.3-3
  - clamav-db-0.97.3-3
  - clamav-devel-0.97.3-3
  - clamav-milter-0.97.3-3
  - clamd-0.97.3-3
  - clamsmtp-1.10-6
  - facter-1.6.10
  - hiera-1.0.0
  - jenkins-1.474-1
  - pdsh-2.28-0
  - pssh-2.3.1-0
  - puppetlabs-stdlib-2.2.1-0
  - rubygem-rack-1.1.3-1
  - rubygems-1.3.7-4
- Updated to the new Puppet Labs release key for Yum.
- Updated Puppet to 2.7.17 to fix the following CVEs:
  - CVE-2012-3864
  - CVE-2012-3865
  - CVE-2012-3866
  - CVE-2012-3867
- First port of the SIMP docs to Publican output!
- Updated OS detection process further to search anaconda.log if
  it cannot be determined in dmesg. Also added %end to %packages,
  %pre, and %post sections for all kickstart files.
- Updated the repodetect script to not assume 'CentOS' by default.
  Also, some hardware fills the dmesg buffer quickly so we now read
  10485760 bytes of the buffer so that we can find the User ID more
  quickly for OS detection.
- Added 'lsb' and 'createrepo' as dependencies.
- 'lsb' is needed since we use a lsb fact in the %post section.
- The %post section now creates a stub 'Updates' repo if it doesn't
  already exist. This fixes an issue where your base repo is actually
  hosted elsewhere.

* Wed May 30 2012 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.0.2-beta
- Added a file /etc/simp/simp.version that contains the version from
  this RPM for distribution to the clients.
- Added requires for ruby-ldap and rubygem-hiera to simp-mit
- Moved MIT libraries to %{_usr}/share/simp/tests/modules/mit_common
- Updated the PuppetUtils in MIT library to offer more puppet functionality
- Added 'disable_agent' and 'enable_agent' steps to the MIT common
  library.
- Ensure that, when 'puppet agent' needs to run, it is enabled, and
  when 'puppet apply' needs to run, the agent is disabled.

* Fri Mar 16 2012 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.0.1-0
- Removed all IPv6 blacklisting from the kickstart files since it
  causes issues with bonding.
- Updated documentation to include instructions on what to do if you
  want to build the intial SIMP server from a pre-existing Kickstart
  environment.

* Wed Feb 01 2012 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.0.1-RC1
- Added documentation for using Ganglia
- Added rpms to support cucumber
- Fixed workstation mode on the DVD
- Added MIT utilities for not stomping on existing puppet runs and for allowing
  a local SSH connection to be active and used across test scenarios.
- Added requirements to the main MIT package.

* Thu Jan 19 2012 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.0.1-beta
- Added CentOS6.2 support
- Updated to RHEL6.2
- The following packages have been updated:
  - BackupPC
  - perl-Net-FTP-*
  - Ganglia
  - ClamAV
  - MRepo
  - Jenkins

* Wed Dec 21 2011 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.0.0-0
- Added the 'mit' package to the mix.
- Updated documentation with an upgrade guide for migrating to the new version
  of Puppet.

* Fri Nov 18 2011 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.0.0-rc3
- Fixed quite a few RC2 bugs.
- Now disable ipv6 properly for RHEL6 in the kickstart files by default.

* Mon Nov 14 2011 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.0.0-rc2
- Pulled in the gpxe roms from the 'optional' repo for the libvirt module.

* Mon Nov 07 2011 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.0.0-rc1
- Added Puppet 2.7.7rc1 to fix some issues with directory creation.
- Updated the docs to explain the rationale behind the nightly YUM updates.
- Fixed the puppet client kickstart to point at the client diskdetect file.

* Mon Jul 11 2011 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.0.0-alpha
- First cut.

* Mon Jun 13 2011 Maintenance - 2.0.0-rc1
- Added the DVD build Rakefile to the docs/examples folder.
- Updated the Changelog to note what RHEL release this version is compatible with.
- Updated DVD build docs.

* Sat Jan 22 2011 Maintenance - 2.0.0-beta
- Fixed a few typos in the supplied LDIFs
- Documentation updates
- Added new RPMs to the Ext_RPMs simp-ppolicy-check-password-2.3.43-0.

* Tue Jan 11 2011 Maintenance - 2.0.0-alpha
- Refactored for SIMP-2.0.0-alpha release

* Mon Jan 03 2011 Maintenance 1.3.0-RC1
- First release candidate of 1.3.0
- Added useful LDIFs to %{_usr}/share/doc/simp-<version>/ldifs.

* Wed Jun 23 2010 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.3.0-alpha
- Initial release of 1.3.0
- Documentation is now generated by puppetdoc!
- Modified settings so that users other than root can now see the SIMP
  documentation.

* Fri May 28 2010 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.2.7-0
- Initial release of 1.2.7

* Tue May 11 2010 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.2.6-5
- Documentation updates.

* Mon May 10 2010 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.2.6-4
- Added a 'if' statement to the 'post 'section to preclude inappropriate failure
  messages if httpd can't restart for some reason.

* Mon Apr 27 2010 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.2.6-3
- Now auto-generating Requires: statements for the modules.

* Mon Apr 26 2010 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.2.6-2
- Update to the install section of the spec file for new build script
  compatibility

* Wed Mar 17 2010 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.2.6-1
- Beta release of 1.2.6
- Additional documentation has been added to the docs directory to support
  configuration understanding.
- Now, restart httpd if it's running as well.

* Tue Feb 23 2010 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.2.5-7
- Final release of 1.2.5

* Fri Feb 05 2010 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.2.5-0
- Beta release of 1.2.5

* Thu Jan 14 2010 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.2.4-4
- Final release of 1.2.4

* Wed Jan 06 2010 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.2.4-2
- Beta release of 1.2.4

* Mon Jan 04 2010 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.2.4-1
- Alpha release of 1.2.4

* Tue Dec 15 2009 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.2.3-3
- Beta release of 1.2.3

* Thu Oct 13 2009 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.2.2
- Fixing one bug in pupmod-common and ensuring that this RPM maintains the
  proper versioning requirements.

* Thu Oct 1 2009 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.2.1
- A few minor fixes but, most notably, the addition of Xwindows, VNC, and Mozilla.
- Note: If upgrading from a pre-1.2 system, check %{prefix}/manifests for
  .rpmnew files and carefully update your system.
