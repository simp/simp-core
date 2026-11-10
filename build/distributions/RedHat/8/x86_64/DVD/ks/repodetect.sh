#!/bin/sh
#
# repodetect.sh - write the kickstart repository configuration for this OS
#
# Usage: repodetect.sh VERSION [YUM_SERVER] [LINUX_DIST]
#
#   VERSION     Major OS version number ('8', '9' or '10')
#   YUM_SERVER  (Optional) Empty or 'local' for the SIMP DVD, or the host name
#               (with an optional ':port') of a SIMP yum server
#   LINUX_DIST  (Optional) The OS directory name on the yum server, which is
#               the OS's `os.name` fact: 'RedHat', 'AlmaLinux', 'Rocky',
#               'OracleLinux' or 'CentOS'.  Detected from the installer when
#               not given.
#
# Writes:
#
#   /tmp/repo-include      `repo` kickstart commands for the repositories that
#                          aren't on the OS DVD.  The kickstart's own `url` or
#                          `cdrom` command provides BaseOS and AppStream (from
#                          the DVD's .treeinfo).
#   /tmp/simp-packages     The SIMP packages to install, or nothing when the
#                          yum server has no SIMP repository
#
# Expected yum server layout (VERSION and ARCH are e.g. '9' and 'x86_64'):
#
#   /yum/LINUX_DIST/VERSION/ARCH/            A copy of the OS DVD (.treeinfo,
#                                            images/, BaseOS/, AppStream/)
#   /yum/SIMP/LINUX_DIST/VERSION/ARCH/CRB    CodeReady Builder (named
#                                            'PowerTools' on EL8)
#   /yum/SIMP/LINUX_DIST/VERSION/ARCH/epel   EPEL
#   /yum/SIMP/LINUX_DIST/VERSION/ARCH/openvox  OpenVox (yum.voxpupuli.org)
#   /yum/SIMP/LINUX_DIST/VERSION/ARCH/SIMP   SIMP packages (optional)
#

unknown='REPODETECT_UNKNOWN_OS_TYPE'
distro="$unknown"

version="$1"
yum_server="$2"
if [ $# -gt 2 ] && [ -n "$3" ]; then distro="$3"; fi
arch="$(uname -m)"

case "$version" in
  8|9|10) ;;
  '')
    echo "ERROR: You must pass the major OS VERSION ('8', '9' or '10') as the first argument" >&2
    exit 1
    ;;
  *)
    echo "ERROR: Unsupported OS VERSION '${version}'; expected '8', '9' or '10'" >&2
    exit 1
    ;;
esac

if [ "$distro" = "$unknown" ]; then
  os_id=''
  if [ -r /etc/os-release ]; then
    # shellcheck source=/dev/null
    os_id="$(. /etc/os-release && echo "$ID")"
  fi

  case "$os_id" in
    rhel)      distro=RedHat ;;
    almalinux) distro=AlmaLinux ;;
    rocky)     distro=Rocky ;;
    ol)        distro=OracleLinux ;;
    centos)    distro=CentOS ;;
    *)
      if grep -qs 'Red Hat' /etc/redhat-release; then
        distro=RedHat
      else
        echo "WARNING: Unable to determine the OS distribution (ID='${os_id}'); assuming RedHat" >&2
        distro=RedHat
      fi
      ;;
  esac
fi

# Name of the CodeReady Builder repository directory
if [ "$version" = '8' ]; then
  crb='PowerTools'
else
  crb='CRB'
fi

if [ -z "$yum_server" ] || [ "$yum_server" = 'local' ]; then
  simp_uri='file:///mnt/source/SimpRepos'
else
  simp_uri="https://${yum_server}/yum/SIMP/${distro}/${version}/${arch}"
fi

cat << EOF > /tmp/repo-include
repo --name="crb" --baseurl="${simp_uri}/${crb}" --noverifyssl
repo --name="epel" --baseurl="${simp_uri}/epel" --noverifyssl
repo --name="openvox" --baseurl="${simp_uri}/openvox" --noverifyssl
EOF

# The SIMP repository is optional, so that a host can be kickstarted before
# SIMP packages are published for its OS.
: > /tmp/simp-packages
simp_repomd="${simp_uri}/SIMP/repodata/repomd.xml"
if curl -kfsS -o /dev/null "$simp_repomd" 2>/dev/null; then
  echo "repo --name=\"simp\" --baseurl=\"${simp_uri}/SIMP\" --noverifyssl" >> /tmp/repo-include
  cat << EOF > /tmp/simp-packages
simp
simp-adapter
EOF
else
  echo "WARNING: No SIMP repository at '${simp_uri}/SIMP'; SIMP packages will not be installed" >&2
fi
