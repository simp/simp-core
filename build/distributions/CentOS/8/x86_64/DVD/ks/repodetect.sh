#!/bin/sh
#
# repodetect.sh - determine kickstart repos based on your OS
#
# Usage: repodetect.sh VERSION [YUM_SERVER] [LINUX_DIST]
#
#   VERSION     Major OS version number (e.g., '8', '7')
#   YUM_SERVER  (Optional) empty, 'local', or a URI of a yum server
#   LINUX_DIST  (Optional) Forces Linux  distro (e.g., 'CentOS', 'RedHat')
#
# Supported OSes: LINUX_DIST: [CentOS, RedHat],  VERSION: [7, 8]
#

unknown="REPODETECT_UNKNOWN_OS_TYPE"
distro="$unknown"
arch="x86_64"

version="$1"
yum_server="$2"
if [ $# -gt 2 ]; then distro="$3"; fi
arch="$(uname -m)" # (e.g., "x86_64")

if [ -z "$version" ]; then
  echo "ERROR: You must pass the major OS VERSION (e.g., '8','7') as the first argument"
  exit 1
fi

if [ "$distro" == "$unknown" ]; then
  osline="$(dmesg -s 10485760 | grep '(Kernel Module GPG key)')" ||:
  if grep -q 'Red Hat' /etc/redhat-release \
    || grep -q "url is.*RedHat" /tmp/anaconda.log \
    || [[ "$osline" =~ RedHat ]] \
    || [ -f /tmp/RedHat.osbuild ]
  then
    distro=RedHat
  elif grep -q 'CentOS' /etc/redhat-release \
    || grep -q "url is.*CentOS" /tmp/anaconda.log \
    || [[ "$osline" =~ CentOS ]] \
    || [ -f /tmp/CentOS.osbuild ]
  then
    distro=CentOS
  elif [ "$distro" == "$unknown" ]; then
    echo "WARNING: Unable to determine distro of OS; Assuming CentOS"
    distro=CentOS
  fi
fi

if [ -z "$yum_server" ] || [ "$yum_server" == 'local' ]; then
  uri_header="file:///mnt/source"
  if [ "$version" == "7" ]; then
    local_header=$uri_header/SIMP/$arch
  else
    local_header="$uri_header/SimpRepos"
  fi
else
  uri_header="https://$yum_server/yum/$distro/$version/$arch"
  local_header="https://$yum_server/yum/SIMP/$distro/$version/$arch"
fi

if [ "$distro" == RedHat ]; then

  case $version in
    '8' )
      cat << EOF > /tmp/repo-include
repo --name="baseos"   --baseurl="$uri_header/BaseOS" --noverifyssl
repo --name="appstream"   --baseurl="$uri_header/AppStream" --noverifyssl
repo --name="epel"   --baseurl="$local_header/epel" --noverifyssl
repo --name="epel-modular"   --baseurl="$local_header/epel-modular" --noverifyssl
repo --name="extras"   --baseurl="$local_header/extras" --noverifyssl
repo --name="postgresql"   --baseurl="$local_header/postgresql" --noverifyssl
repo --name="powertools"   --baseurl="$local_header/PowerTools" --noverifyssl
repo --name="puppet"   --baseurl="$local_header/puppet" --noverifyssl
repo --name="simp"   --baseurl="$local_header/SIMP" --noverifyssl
EOF
    ;;
    '7' )
      cat << EOF > /tmp/repo-include
repo --name="HighAvailability" --baseurl="$uri_header/addons/HighAvailability"
repo --name="ResilientStorage" --baseurl="$uri_header/addons/ResilientStorage"
repo --name="Base" --baseurl="$uri_header"
repo --name="simp" --baseurl="$local_header"
EOF
    ;;
  esac

elif [ "$distro" == CentOS ]; then

  case $version in
    '8' )
      cat << EOF > /tmp/repo-include
repo --name="baseos"   --baseurl="$uri_header/BaseOS" --noverifyssl
repo --name="appstream"   --baseurl="$uri_header/AppStream" --noverifyssl
repo --name="epel"   --baseurl="$local_header/epel" --noverifyssl
repo --name="epel-modular"   --baseurl="$local_header/epel-modular" --noverifyssl
repo --name="extras"   --baseurl="$local_header/extras" --noverifyssl
repo --name="powertools"   --baseurl="$local_header/PowerTools" --noverifyssl
repo --name="postgresql"   --baseurl="$local_header/postgresql" --noverifyssl
repo --name="puppet"   --baseurl="$local_header/puppet" --noverifyssl
repo --name="simp"   --baseurl="$local_header/SIMP" --noverifyssl
EOF
    ;;
    '7' )
      cat << EOF > /tmp/repo-include
repo --name="Server" --baseurl="$uri_header"
repo --name="simp" --baseurl="$local_header"
repo --name="Updates" --baseurl="$uri_header/Updates" --noverifyssl
EOF
    ;;
  esac

fi
