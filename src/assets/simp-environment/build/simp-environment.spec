%global selinux_policyver %(%{__sed} -e %'s,.*selinux-policy-\\([^/]*\\)/.*,\\1,' %/usr/share/selinux/devel/policyhelp 2>/dev/null || echo 0.0.0)
%global selinux_variants targeted

%define selinux_policy_short simp-environment
%define selinux_policy %{selinux_policy_short}.pp

Summary: The SIMP Environment Scaffold
Name: simp-environment
Version: 6.0.0
Release: 0 
License: Apache License 2.0
Group: Applications/System
Source: %{name}-%{version}-%{release}.tar.gz
Buildroot: %{_tmppath}/%{name}-%{version}-%{release}-buildroot
Requires: libselinux-utils
Requires: policycoreutils
Requires: pupmod-simp-simp >= 3.0.0
Requires: pupmod-simp-pki >= 6.0.0-0
Requires: createrepo
Requires: simp-rsync >= 5.0.0-3
Requires: simp-utils >= 5.0.0-5
Requires: rubygem(simp-cli) >= 1.0.0-0
Requires: openssl
Requires(pre,preun,post,postun): simp-adapter
Requires(post): coreutils
Requires(post): glibc-common
Requires(post): pam
Requires(post): libsemanage
Requires(post): selinux-policy >= %{selinux_policyver}
Requires(post): selinux-policy-targeted >= %{selinux_policyver}
Requires(postun): policycoreutils
BuildRequires: selinux-policy-targeted
%if "%{?rhel}%{!?rhel:0}" > "6"
BuildRequires: selinux-policy-devel
%endif
Provides: simp-bootstrap = %{version}-%{release}
Provides: simp_bootstrap = %{version}-%{release}
Obsoletes: simp-bootstrap < %{version}-%{release}
Obsoletes: simp_bootstrap < %{version}-%{release}
Obsoletes: simp_config < %{version}-%{release}
Obsoletes: simp-config < %{version}-%{release}
Buildarch: noarch

Prefix: /usr/share/simp/environments/simp
%description

Contains template files and directories for initially setting up a SIMP server
using a default 'simp' Puppet Environment.

%prep
%setup -q

%build
cd build/selinux
  make -f %{_datadir}/selinux/devel/Makefile
cd -

%install
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

# Make your directories here.
mkdir -p %{buildroot}/%{prefix}/hieradata/hostgroups
mkdir -p %{buildroot}/%{prefix}/simp_autofiles
mkdir -p %{buildroot}/%{prefix}/hieradata/compliance_profiles
mkdir -p %{buildroot}/%{_var}/simp/environments/simp/site_files/krb5_files/files/keytabs

# Now install the files.
cp -r environments/* %{buildroot}/`dirname %{prefix}`

cd build/selinux
  install -p -m 644 -D %{selinux_policy} %{buildroot}/%{_datadir}/selinux/packages/%{selinux_policy}
cd -

%clean
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

%files
%defattr(0640,root,puppet,0750)
%{prefix}
%attr(0750,puppet,puppet) %{prefix}/simp_autofiles
%attr(0750,root,puppet) %{_var}/simp/environments/simp/site_files
%attr(0750,root,puppet) %{_var}/simp/environments/simp/site_files/krb5_files
%attr(0750,root,puppet) %{_var}/simp/environments/simp/site_files/krb5_files/files
%attr(0750,root,puppet) %{_var}/simp/environments/simp/site_files/krb5_files/files/keytabs
%config(noreplace) %{prefix}/environment.conf
%config(noreplace) %{prefix}/hieradata/RedHat/6.yaml
%config(noreplace) %{prefix}/hieradata/hosts/puppet.your.domain.yaml
%config(noreplace) %{prefix}/hieradata/hostgroups/default.yaml
%config(noreplace) %{prefix}/hieradata/simp/site/default.yaml
%config(noreplace) %{prefix}/hieradata/simp/simp.yaml
%config(noreplace) %{prefix}/hieradata/simp/simp-lite.yaml
%config(noreplace) %{prefix}/hieradata/simp/poss.yaml
%config(noreplace) %{prefix}/hieradata/default.yaml
%config(noreplace) %{prefix}/manifests/site.pp
%config(noreplace) %{prefix}/FakeCA/togen
%config(noreplace) %{prefix}/FakeCA/usergen
%config(noreplace) %{prefix}/hieradata/compliance_profiles/nist_800_53_rev4.yaml
%config(noreplace) %{prefix}/hieradata/compliance_profiles/disa_stig_el7.yaml
%defattr(0640,root,root,0750)
%{_datadir}/selinux/*/%{selinux_policy}
%{prefix}/FakeCA
%attr(0750,-,-) %{prefix}/FakeCA/clean.sh
%attr(0750,-,-) %{prefix}/FakeCA/gencerts_common.sh
%attr(0750,-,-) %{prefix}/FakeCA/gencerts_nopass.sh
%attr(0750,-,-) %{prefix}/FakeCA/usergen_nopass.sh

%post
PATH=/opt/puppetlabs/bin:$PATH
export PATH

/usr/sbin/semodule -n -i %{_datadir}/selinux/packages/%{selinux_policy}
if /usr/sbin/selinuxenabled; then
  /usr/sbin/load_policy
  /sbin/fixfiles -R %{name} restore || :
  /sbin/fixfiles restore %{_var}/simp || :
fi

# Ensure that the cacertkey has some random gibberish in it if it doesn't
# exist.
if [ ! -e "%{prefix}/FakeCA/cacertkey" ]; then
  dd if=/dev/urandom count=24 bs=1 status=none | openssl enc -a -out "%{prefix}/FakeCA/cacertkey"
fi

chmod 2770 %{prefix}

codedir=`puppet config print codedir`
if [ ! -d $codedir ]; then
  codedir=`puppet config print confdir`
fi

if [ ! -a "${codedir}/environments/production" ]; then
  (
    cd "${codedir}/environments"
    ln -s simp production
  )
fi

# Switch things over to the new setup.
arch=`uname -p`;
version=`/usr/bin/facter lsbdistrelease 2> /dev/null`;
majversion=`/usr/bin/facter lsbmajdistrelease 2> /dev/null`;
os=`/usr/bin/facter operatingsystem 2> /dev/null`;
www_dir="/var/www/yum";
base="${www_dir}/${os}";

if [ -d $base ] && [ ! -h $base/$majversion ]; then
  if [ -f $base/$majversion/$arch/.treeinfo ]; then
    version=`grep version $base/$majversion/$arch/.treeinfo | cut -f3 -d' '`;
  fi

  cd $base;
  mv $majversion $version;

  ln -s $version $majversion;
fi

# Check to see if the 'SIMP' repo is on the system and correct.
if [ -d "${www_dir}/SIMP" ]; then
  cd "${www_dir}/SIMP";
  if [ -d "${www_dir}/SIMP/repodata" ]; then
    rm -rf repodata;
  fi

  if [ -d i386 ]; then
    (
      cd i386;
      for file in ../noarch/*; do ln -sf $file .; done
      createrepo --update -p .;
      chown -R root:apache *;
      chmod -R g+rX *;
    )
  fi
  if [ -d x86_64 ]; then
    (
      cd x86_64;
      for file in ../noarch/*; do ln -sf $file .; done
      createrepo --update -p .;
      chown -R root:apache *;
      chmod -R g+rX *;
    )
  fi
else
  if [ ! -d "${www_dir}/SIMP" ]; then
    echo "Warning: Could not find ${www_dir}/SIMP on this system, you will need";
    echo "  to ensure that your 'SIMP' repository has repodata in i386 and";
    echo "  x86_64 as well as having symlinked noarch to both."
  fi
fi

# Needed for migrating the environment data into the codedir
/usr/local/sbin/simp_rpm_helper --rpm_dir=%{prefix} --rpm_section='post' --rpm_status=$1 --preserve --target_dir='.'

%postun
# Post uninstall stuff
if [ $1 -eq 0 ]; then
  /usr/sbin/semodule -n -r %{selinux_policy_short}
  if /usr/sbin/selinuxenabled; then
    /usr/sbin/load_policy
    /sbin/fixfiles -R %{name} restore || :
  fi
fi

# Needed for cleaning up the data from codedir as appropriate
/usr/local/sbin/simp_rpm_helper --rpm_dir=%{prefix} --rpm_section='postun' --rpm_status=$1 --preserve --target_dir='.'

%changelog
* Tue Jan 10 2017 Nick Miller <nick.miller@onyxpoint.com> - 6.0.0-Alpha
- Moved the default location of keydist from the normal puppet environment and
  modulepath to /var/simp/environments/simp/site_files/pki_files/files/keydist,
  which won't be overwritten or deleted when using r10k and a control repo.

* Fri Jan 06 2017 Trevor Vaughan <tvaughan@onyxpoint.com> - 6.0.0-Alpha
- Eliminated the 'localusers' capability
- Changed the name to simp-environment
- Ripped out all of the legacy materials
- Updated to use the simp-adapter RPM helper

* Tue Dec 06 2016 Nick Markowski <nmarkowski@keywcorp.com> - 6.0.0-Alpha
- Updated nist compliance map to reference new gnome::enable_screensaver
  parameter.
- Updated compliance maps to API 1.0.0 format
- Updated hieradata to reflect changes in puppetdb (SIMP-1450)

* Thu Sep 01 2016 Ralph Wright <ralph.wright@onyxpoint.com> - 5.3.2-0
- Modified compliance files to handle updated audit rules.

* Mon Aug 15 2016 Trevor Vaughan <tvaughan@onyxpoint.com> - 5.3.1-0
- Relocated the 'site_files' directory and created a custom selinux policy for
  the included files.

* Fri Aug 12 2016 Nick Miller <nick.miller@onyxpoint.com> - 5.3.1-0
- Added keytab storage to site_files
- Corrected site_files implementation to work with our krb5 implementation

* Wed Aug 10 2016 Lisa Umberger <lisa.umberger@onyxpoint.com> - 5.3.1-0
- Added a compliance profile for DISA STIG.

* Thu Jul 07 2016 Trevor Vaughan <tvaughan@onyxpoint.com> - 5.3.0-0
- Moved to semantic versioning
- Added support for a 'site_files' module path in the primary 'simp'
  environment for modules like krb5 and pki that have files in them that should
  not be managed by r10k or code manager.

* Mon Apr 25 2016 Chris Tessmer <chris.tessmer@onyxpoint.com> - 5.2.1-5
- Required 'sudo' to resolve ordering race that overwrote '/etc/sudoers'.

* Fri Jan 29 2016 Ralph Wright <ralph.wright@onyxpoint.com> - 5.2.1-4
- Added suppport for compliance module

* Fri Dec 04 2015 Chris Tessmer <chris.tessmer@onyxpoint.com> - 5.2.1-3
- Migrated from 'common::' to 'simplib::'

* Mon Nov 09 2015 Trevor Vaughan <tvaughan@onyxpoint.com> - 5.2.1-2
- Fixed a regression that reverted the 'post' section of the RPM to using
  /srv/www instead of /var/www.

* Tue Jun 09 2015 Trevor Vaughan <tvaughan@onyxpoint.com> - 5.2.1-1
- Made some minor fixes to prepare for public release.
- Added a global Exec default for the command path.
- Refactored the FakeCA to not include any code from the OpenSSL package.

* Thu Apr 09 2015 Chris Tessmer <chris.tessmer@onyxpoint.com> - 5.2.1-0
- Ensured SIMP-ready Puppet environment paths on install as well as upgrade.

* Thu Apr 02 2015 Trevor Vaughan <tvaughan@onyxpoint.com> - 5.2.0-0
- Added PuppetDB support and ensured that the default Puppet server is running
  PuppetDB.

* Fri Feb 27 2015 Nick Markowski <nmarkowski@keywcorp.com> - 5.1.0-0
- Modified the default simp Mcollective hieradata file to include SSL config.

* Fri Feb 06 2015 Trevor Vaughan <tvaughan@onyxpoint.com> - 5.1.0-0
- Create a consistent environment framework for SIMP called 'simp'
- Symlink this new environment to 'production' by default.
- Remove the Passenger SELinux custom policy since we no longer use Passenger
  by default.
- Remove all Passenger and Apache requirements
- Now include the FakeCA in the new 'simp' environment as an example
- Obsolete simp-config
- Add initial build password complexity settings if the system is kickstarting
  and not yet managed by Puppet
- Update the SIMP environment FakeCA to drop keys into the PKI module's
  'keydist' directory.
- Set up a symlink to the PKI module's 'keydist' directory for ease of use.
- Update the default hiera.yaml file to use the hieradata in the environments.

* Mon Dec 15 2014 Kendall Moore <kmoore@keywcorp.com> - 5.0.0-7
- Updated the Passenger SELinux policy to allow httpd to write puppet log files.

* Mon Dec 15 2014 Nick Markowski <nmarkowski@keywcorp.com> - 5.0.0-7
- Updated simp user and group id to 1777 from 777.

* Thu Dec 04 2014 Trevor Vaughan <tvaughan@onyxpoint.com> - 5.0.0-6
- Updated to convert log_server (string) to log_servers (array)
  throughout Hiera. This will *not* convert any sub log_server entries
  since there is no way to determine if this is ours or not.

* Fri Oct 31 2014 Trevor Vaughan <tvaughan@onyxpoint.com> - 5.0.0-5
- Added support for Hiera SSL keys in the keydist directory.
- Added a default setup for Hiera based on the host SSL keys.

* Thu Oct 30 2014 Chris Tessmer <ctessmer@onyxpoint.com> - 5.0.0-5
- Updated the simp-passenger.te SELinux policy to allow Passenger/Puppet to
  create and rmdir under /var/lib/puppet.

* Mon Aug 25 2014 Trevor Vaughan <tvaughan@onyxpoint.com> - 5.0.0-4
- Added a setting to remove the allow virtual package warnings.

* Sat Aug 02 2014 Trevor Vaughan <tvaughan@onyxpoint.com> - 5.0.0-3
- Removed common::runlevel class inclusion
- Changed common::runlevel::default to just common::runlevel

* Thu Jul 24 2014 Kendall Moore <kmoore@keywcorp.com> - 5.0.0-2
- Moved references of /srv/www/yum to /var/www/yum.
- Enabled/disabled SIMP yum repos depending on the existence of /var/www/yum/SIMP.

* Mon Jul 21 2014 Trevor Vaughan <tvaughan@onyxpoint.com> - 5.0.0-2
- Updated the SELinux policy for passenger to allow httpd_t to do ALL
  THE THINGS.
- Changed web references from /srv to /var
- Upated to use the new /var/simp/rsync path and support splitting the
  rsync paths by fact.

* Mon Jul 14 2014 Trevor Vaughan <tvaughan@onyxpoint.com> - 5.0.0-1
- Added stringify_facts = false as the default in puppet.conf to
  support complex facts in Facter 2.

* Fri May 16 2014 Trevor Vaughan <tvaughan@onyxpoint.com> - 5.0.0-0
- Updated the sameple puppet.conf.rpmnew file to support directory
  environments since Puppet 3.6 deprecated the 'manifest' option.
- Linked the usual suspects into the 'production' directory
  environment if the targets did not already exist.
- Removed management of /etc/puppet/modules since puppet now supplies
  this.
- Added policycoreutils-devel as a dependency for RHEL 7.

* Tue May 06 2014 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.1.0-2
- Added hiera defaults for logstash.
- Moved the old Local repo over to being a SIMP repo.
- Generated a full default Hiera configuration.
- Removed the call to pki::pre in base_config since it no longer exists.
- Removed openldap::slapo::lastbind from ldap_common since it
  constantly generates LDAP updates and subsequently generates audit
  records. Users can add it back in manually if they need it.

* Tue Feb 04 2014 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.1.0-1
- Modified the ldap* base classes to use the new openldap module.
- Moved the hiera data from /etc/puppet/hiera to /etc/puppet/hieradata
  to match the documentation on the Internet.
- Ensure that hieradata/simp/%{module_name}/default works.
- The default 'web_server' class has been removed since Hiera can now
  handle all settings properly.
- All references to pupmod::server were replaced by pupmod::master due
  to pupmod-pupmod being rewritten.
- The call to timezone::set_timezone was changed to timezone::set.

* Thu Dec 12 2013 Morgan Haskel <morgan.haskel@onyxpoint.com> - 4.1.0-0
- Added default LDAP referral chaining for slave nodes.
- Fixed the LDAP slave RID to be adjustable.

* Tue Nov 12 2013 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.1.0-0
- Migrated default data into Hiera for default_classes.
- Removed all calls to the common::sysctl::* defines and updated the
  includes to point to the new common::sysctl class. Hiera should be
  used for manipulating the individual entities.

* Mon Nov 04 2013 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.1.0-0
- Added a default hiera data file for 'sec'
- Modified all calls to 'auditd' to use the new hiera-friendly
  includes.
- Removed the auditd rsync service from the puppet server since we
  haven't served that out for quite a while.

* Sun Oct 06 2013 Trevor Vaughan <tvaughan@onyxpoint.com> - 3.0.0-1
- Moved /etc/puppet/manifests/hiera to /etc/puppet/hieradata to match the rest
  of the world.
- Modified the 'fqdn' lookup in hiera.yaml to be 'clientcert'.

* Fri Sep 27 2013 Nick Markowski <nmarkowski@keywcorp.com> 3.0.0-0
- Replaced Extdata with Hiera

* Tue Sep 24 2013 Kendall Moore <kmoore@keywcorp.com> 2.0.3-7
- Upgraded dependencies to puppet 3.X and puppet-server 3.X because of an
  upgrade to use hiera instead of extdata.
- Ensure that the hiera.yaml file is put in /etc/puppet and then linked to
  /etc as well.

* Sat Sep 07 2013 Trevor Vaughan <tvaughan@onyxpoint.com> 2.0.3-6
- Fixed a bug in the 'security_relevant_logs' setting of extdata where the
  escapes were interfering with proper log collection.
- Added all 'sudo' logs to the 'security_relevant_logs' variable.

* Tue Sep 03 2013 Nick Markowski <nmarkowski@keywcorp.com> 2.0.3-6
- Incorporated a lastbind manifest to the default ldap server

* Fri Jun 28 2013 Kendall Moore <kmoore@keywcorp.com> 2.0.3-5
- Updated the simp-passenger.te SELinux policy to allow for the context passenger_t
  access to the context ssh_keygen_exec_t for these file permissions: execute, execute_no_trans, open, read.
- The following avc errors are known to appear in the audit log but have not
  been found to cause any issues.
    - avc:  denied  { relabelto } for  pid=7908 comm="ruby" name="ca_crt.pem"
      dev=dm-6 ino=163921 scontext=unconfined_u:system_r:passenger_t:s0
      tcontext=system_u:object_r:puppet_var_lib_t:s0 tclass=file
    - avc:  denied  { relabelfrom } for pid=7908 comm="ruby" name="ca_crt.pem"
      dev=dm-6 ino=163921 scontext=unconfined_u:system_r:passenger_t:s0
      tcontext=unconfined_u:object_r:puppet_var_lib_t:s0 tclass=file
    - avc:  denied  { relabelfrom } for  pid=7908 comm="ruby" name="master.pid"
      dev=dm-6 ino=114729 scontext=unconfined_u:system_r:passenger_t:s0
      tcontext=unconfined_u:object_r:puppet_var_run_t:s0 tclass=file
    - avc:  denied  { relabelto } for  pid=7908 comm="ruby" name="master.pid"
      dev=dm-6 ino=114729 scontext=unconfined_u:system_r:passenger_t:s0
      tcontext=system_u:object_r:puppet_var_run_t:s0 tclass=file
    - avc:  denied  { getattr } for  pid=8108 comm="ruby"
      path="/var/run/puppet/master.pid" dev=dm-6 ino=114729
      scontext=unconfined_u:system_r:passenger_t:s0
      tcontext=system_u:object_r:puppet_var_run_t:s0 tclass=file

* Fri May 17 2013 Adam Yohrling <adam.yohrling@onyxpoint.com> 2.0.3-4
- Added support for changing the LDAP sync user to connect to legacy
  systems.

* Mon May 13 2013 Trevor Vaughan tvaughan@onyxpoint.com 2.0.3-3
- Added SELinux support for the way Passenger needs to work with the
  system.
- This is *not* a generic Passenger module but one that is designed to
  explicitly work with Puppet as we have designed it into the system.

* Tue May 07 2013 Nick Markowski <nmarkowski@keywcorp.com>
2.0.3-2
- Removed pull_keys.  Openssh now directly authenticates via ldap.

* Thu Dec 06 2012 Maintenance
2.0.3-1
- Updated to fix lack of inclusion of 'pupmod::client' in
  base_config.pp.

* Wed Nov 28 2012 Maintenance
2.0.3-0
- Added a dependency on pupmod-pupmod-2.1.0-0
- Modified calls to pupmod::* functions to use the new parameterized
  classes instead of the previous defines.

* Wed Jul 25 2012 Maintenance - 2.0.2-3
- Edited the post section so the baseurls of the repofiles would
  add the architecture to the path when it did not already exist.
- Now prune the /etc/ssh/ssh_known_hosts file if you have Puppet
  collecting all of your keys.

* Thu Jun 28 2012 Maintenance
2.0.2-2
- Ensure that the simp_def.csv is not overwritten on update.
- Edited the post section so the baseurls of the repofiles would not
  be changed on an upgrade.

* Wed May 30 2012 Maintenance
2.0.2-0
- Added a section to 'site.pp' to create an /etc/simp directory.
- Added a file, /etc/simp/simp.version that's generated from the
  'simp_version()' server function and contains the version of SIMP as
  the server knows it.
- Modified pull_keys in base_config.pp to be a parameterized class
  call.

* Tue Mar 06 2012 Maintenance
2.0.1-0
- Updated puppet_server.pp to include the rsync server statement
  for jenkins
- Updated the name to simp-bootstrap for consistency.

* Wed Feb 15 2012 Maintenance
2.0.0-8
- Commented out the 'mount' statement in base_config. It's just too
  difficult to do any sort of assumption about mount statments in a
  stock build.
- Removed all references to the $newserver fact and the creation of
  the newserver dynamic fact from the puppet server manifest.
- Added $puppet_server and $puppet_server_ip to vars.pp and removed
  $puppet_servers.
- Added a $puppet_server_alt_names variable to allow users to add any
  required name to /etc/hosts for the puppet server.

* Tue Dec 20 2011 Maintenance
2.0.0-7
- Added a variable 'primary_ipaddress' to advanced_vars.pp that uses extlookup
  to pull its value or falls back to $::ipaddress as a default.
- Added extlookup settings to site.pp that will allow you to override variables
  in the following order (from more specific to less specific):
  - /etc/puppet/manifests/extdata/hosts/FQDN.csv
  - /etc/puppet/manifests/extdata/hosts/HOSTNAME.csv
  - /etc/puppet/manifests/extdata/domains/DOMAIN.csv
  - /etc/puppet/manifests/extdata/default.csv
- Added 'simp' to the 'wheel' group so that it can 'su' to root directly with
  the new 'su' PAM settings.

* Fri Nov 18 2011 Maintenance
2.0.0-6
- Ensure that we whack the old puppetd cron job using ralsh.
- Disable sssd by default and enable nscd.

* Sun Nov 06 2011 Maintenance
2.0.0-5
- Removed the 'attrs' line from the ldap_slave class so that it will properly
  copy the password policy entries from the master server. This is extremely
  important since, otherwise, the noExpire password policy will not function
  and you may end up locking out the hostAuth user.

* Sat Oct 08 2011 Maintenance
2.0.0-4
- Add a stanza to ldap_server.pp that adds an unlimited query capability for
  $ldap_bind_dn so that akeys can pull down all user keys.
- Update to wrap the ldap.conf segment in base_config.pp with a section that
  ignores it if using SSSD.

* Fri Aug 12 2011 Maintenance
2.0.0-3
- Added the variable $runpuppet_print_stats = 'true' to kickstart_server.pp to
  enable stats in the runpuppet kickstart file. Simply remove or set to 'false'
  to revert to the old way of doing things.
- Updated default version to RHEL5.7
- Removed the incrond 'watch_local_keys' from default_classes and moved it into
  the openldap module since that was more appropriate.

* Fri Jun 24 2011 Maintenance
2.0.0-2
- Stunnel now listens on all interfaces by default.
- Removed common::resolv::add_entry which has been replaced by
  common::resolv::conf.
- Updated secure_config to ensure that pam::wheel is called with
  the 'administrators' group.

* Wed Apr 27 2011 Maintenance - 2.0.0-1
- Added a class svckill_ignore to default_classes and now include it in
  secure_config by default. This provides a list of services that should
  usually be disabled but which have bad 'status' return codes.
- Added the $use_sssd variable to vars.pp and set it to 'true' by default.
- Set $use_nscd to false by default in vars.pp
- Added logic to base_config.pp to properly set up SSSD vice NSCD.
- Added a global exec to disable SELinux if it is currently enabled. This
  seemed appropriate since we really need it to be off to operate properly.
- Updated the puppet_servers.pp to include randomly generated rsync passwords
  to correspond with the changes for securing rsync. This is important to do
  for any sensitive rsync area. The affected areas are:
    - openldap
    - $domain
    - apache
    - tftpboot
    - dhcpd
- Updated the localusers file with additional details about the new ability to
  prevent user password expiration completely.
- Updated sudoers rule to allow admins to run puppetca
- Added %post code to check and see if Local is correct on the system.
- Updated site to look for Local repos in Local/noarch and
  Local/${architecture} instead of in Local.
- Updated 'Updates' repo to look in 'lsbmajdistrelease' instead of
  'lsbdistrelease' so that RedHat updates do not break the repo path.

* Tue Jan 11 2011 Maintenance - 2.0.0-0
- Refactored for SIMP-2.0.0-alpha release
- Split 'vars.pp' into 'vars.pp' and 'advanced_vars.pp'

* Wed Dec 8 2010 Maintenance 1.0-4
- Moved ntpd::client out of base_config and into the default and puppet nodes
  so that users can now create a separate NTP server. This also means that
  users need to call ntpd::add_servers on a node specific basis.
- Added an incron rule to watch /etc/ssh/local_keys and copy keys to
  /etc/ssh/auth_keys in real time.
- Ensure that SSL access is enabled by default for 'web_server'.
- Get rid of /5 -> 5.2 symlink

* Tue Nov 09 2010 Maintenance 1.0-3
- Modified the post install to be more careful about chowning all of /etc/puppet.

* Thu Sep 09 2010 Maintenance
1.0-2
- Added deprecation notice to tcpwrappers::tcpwrappers_allow

* Wed Jul 14 2010 Maintenance
1.0-1
- Updated the default puppet server to include an rsync space for freeradius with a password.
- Updated default values for 'ldapuri' and 'dns_servers' in vars.pp.

* Thu Jul 01 2010 Maintenance
1.0-0
- Added support for including all hosts public ssh keys in each other's /etc/ssh/ssh_known_hosts files by default.
- puppet/bootstrap/manifests/nodes/default_classes/puppet_servers.pp
  now creates /etc/puppet/facts/newserver.rb based on variables in
  vars.pp so that clustering can work.
- Modified vars.pp to meet the needs of clustering. Variable
  'puppet_server_ip' is now deprecated.  Variables 'puppet_servers',
'search_servers', and 'quiet_server_search' were added.
- Updated default.pp and puppet_servers.pp to call common::sysctl::net::conf
  with default settings
- Updated default_classes/ldap_server.pp to call
  common::sysctl::net::advanced::conf with default settings
- Added elinks to base_config
- Added dependency on rubygem-passenger
- Updated default.pp and puppet_servers.pp to include
  'rsyslog::stock::log_local' to accomodate the new format.
- Added variable "disable_repos"
- Removed 'import "puppet-sysctl"' from class base_config
- Changed 'include "sec::advanced"' to 'include "sec::stock"' in
  /etc/puppet/manifests/nodes/default_classes/secure_config.pp
- Added variable "puppet_servers"

* Mon May 03 2010 Maintenance
0.4-5
- Modified to use new rubygem packages.

* Thu Feb 18 2010 Maintenance
0.4-4
- Added the variable $ldap_use_certs to vars.pp and modified base_config.pp to
  use it. If set to 'false' (the new default) /etc/ldap.conf will *not* be
  populated with cert file locations. If set to 'true', the default if it's not
  there, the certs will be included in the /etc/ldap.conf configuration for
  backward compatibility with existing configurations.

* Thu Feb 04 2010 Maintenance
0.4-3
- Added a short post script to set things up for the new yum layout by default.

* Mon Jan 11 2010 Maintenance
0.4-2
- Files no longer back up to the filebucket by default.  If you wish to back up
  a particular file, you will need to set 'backup => <valid value>'.

* Wed Jan 06 2010 Maintenance
0.4-1
- Included common::sysctl::net in default.pp and puppet_servers.pp
- If users want this functionality, they will need to update their site
  manifests accordingly!
- Also, included common::sysctl::net::advanced in ldap_server.pp since this has
  been shown to dramatically increase performance and the ability to handle a
  large load.

* Tue Dec 15 2009 Maintenance
0.4-0
- Changed the default updates URL for the repo in site.pp to use the
  lsbdistrelease instead of operatingsystemrelease.
  NOTE: This does require a modification to your YUM repo!
  Instead of /srv/www/yum/RedHat/5, it will now be /srv/www/yum/RedHat/5.2 or
  /srv/www/yum/RedHat/5.4, etc...
- Removed default use of PKI certs by LDAP client configuration to support
  GNOME.
- Added the variable ldap_master_uri to vars.pp to support the explicit
  declaration of a LDAP master for referrals. This defaults to the last entry in
  the ldap_uri variable string.

* Fri Dec 4 2009 Maintenance
0.3-9
- Removed the postfix rsync space from the puppet server defaults.
- Updated vars.pp example to show use of $dns_domain

* Tue Nov 24 2009 Maintenance
0.3-8
- Fixed the default IPTables rule in rsyslog.

* Tue Oct 20 2009 Maintenance
0.3-7
- Abstracted the shared LDAP items in default_nodes.  Users should see no
  difference.
- Added a rsync share for the 'snmp' space for the new module.

* Thu Oct 08 2009 Maintenance
0.3-6
- Now include 'vmware::client' by default.  The class was written to only apply
  to vmware systems by default, so this will not affect any other types of host
  but is one less thing to remember to include.
- Changed the verify variable for syslog to 2.

