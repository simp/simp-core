#!/bin/sh
#
# repodetect.sh - determine kickstart repos based on your OS
#
# Usage: repodetect.sh VERSION [YUM_SERVER] [LINUX_DIST]
#
#   VERSION     Major OS version number (e.g., '8', '7', '6')
#   YUM_SERVER  (Optional) empty, 'local', or a URI of a yum server
#   LINUX_DIST  (Optional) Forces Linux  distro (e.g., 'CentOS', 'RedHat')
#
# Supported OSes: LINUX_DIST: [CentOS, RedHat],  VERSION: [6, 7, 8]
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
  local_header="$uri_header/SIMP/$arch"
  local_name=Local
else
  uri_header="https://$yum_server/yum/$distro/$version/$arch"
  local_header="https://$yum_server/yum/SIMP/$distro/$version/$arch"
  local_name=SIMP
fi

if [ "$distro" == RedHat ]; then

  case $version in
    '8' )
      cat << EOF > /tmp/repo-include
repo --name="epel"   --baseurl="$uri_header/epel" --noverifyssl
repo --name="epel-modular"   --baseurl="$uri_header/epel-modular" --noverifyssl
repo --name="powertools"   --baseurl="$uri_header/PowerTools" --noverifyssl
repo --name="postgresql"   --baseurl="$uri_header/postgresql" --noverifyssl
repo --name="puppet"   --baseurl="$uri_header/puppet" --noverifyssl
repo --name="simpextra"   --baseurl="$uri_header/simp-internet" --noverifyssl
repo --name="$local_name" --baseurl="$local_header" --noverifyssl
EOF
    ;;
    '7' )
      cat << EOF > /tmp/repo-include
repo --name="HighAvailability" --baseurl="$uri_header/addons/HighAvailability"
repo --name="ResilientStorage" --baseurl="$uri_header/addons/ResilientStorage"
repo --name="Base" --baseurl="$uri_header"
repo --name="$local_name" --baseurl="$local_header"
EOF
    ;;
    '6' )
      cat << EOF > /tmp/repo-include
repo --name="HighAvailability" --baseurl="$uri_header/HighAvailability" --noverifyssl
repo --name="LoadBalancer" --baseurl="$uri_header/LoadBalancer" --noverifyssl
repo --name="ResilientStorage" --baseurl="$uri_header/ResilientStorage" --noverifyssl
repo --name="ScalableFileSystme" --baseurl="$uri_header/ScalableFileSystem" --noverifyssl
repo --name="Server" --baseurl="$uri_header/Server" --noverifyssl
repo --name="$local_name" --baseurl="$local_header" --noverifyssl
EOF
     ;;
  esac

elif [ "$distro" == CentOS ]; then

  case $version in
    '8' )
      cat << EOF > /tmp/repo-include
repo --name="epel"   --baseurl="$uri_header/epel" --noverifyssl
repo --name="epel-modular"   --baseurl="$uri_header/epel-modular" --noverifyssl
repo --name="powertools"   --baseurl="$uri_header/PowerTools" --noverifyssl
repo --name="postgresql"   --baseurl="$uri_header/postgresql" --noverifyssl
repo --name="puppet"   --baseurl="$uri_header/puppet" --noverifyssl
repo --name="simpextra"   --baseurl="$uri_header/simp-internet" --noverifyssl
repo --name="$local_name" --baseurl="$local_header" --noverifyssl
EOF
    ;;
    '7' )
      cat << EOF > /tmp/repo-include
repo --name="Server" --baseurl="$uri_header"
repo --name="$local_name" --baseurl="$local_header"
repo --name="Updates" --baseurl="$uri_header/Updates" --noverifyssl
EOF
    ;;
    '6' )
      cat << EOF > /tmp/repo-include
repo --name="Server" --baseurl="$uri_header" --noverifyssl
repo --name="$local_name" --baseurl="$local_header" --noverifyssl
repo --name="Updates" --baseurl="$uri_header/Updates" --noverifyssl
EOF
    ;;
  esac

fi
