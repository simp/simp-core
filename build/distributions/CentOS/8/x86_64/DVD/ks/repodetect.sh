#!/bin/sh
#
# Usage: repodetect.sh <Version> <yum_server>
#
# Version: Mandatory
# Yum_server:
# - Blank or 'Local' -> use a local file source
# - Anything else    -> use this is the URI at which to point.

unknown="REPODETECT_UNKNOWN_OS_TYPE"
# The following line does not work on EL8. The repos will default to
# CentOS if the type is still unknown at the end of the script.
osline=`dmesg -s 10485760 | grep '(Kernel Module GPG key)'`

version=$1
yum_server=$2

if [ $# -gt 2 ]; then
  type=$3
else
  type=$unknown
fi

if [ -z $version ]; then
  echo "Error: You must pass <version> as the first argument";
  exit 1;
fi

arch="i386"
if [ `uname -m` == "x86_64" ]; then arch="x86_64"; fi

# Try to figure out what the os type is
if [ "$type" == "$unknown" ]; then
  grep -q 'Red Hat' /etc/redhat-release
  if [ $? == 0 ]; then
    type="RedHat"
  else
    grep -q 'CentOS' /etc/redhat-release
    if [ $? == 0 ]; then type="CentOS"; fi
  fi
fi

if [ "$type" == "$unknown" ]; then
  grep -q "url is.*RedHat" /tmp/anaconda.log
  if [ $? == 0 ];
    then type="RedHat"
  else
    grep -q "url is.*CentOS" /tmp/anaconda.log
    if [ $? == 0 ]; then type="CentOS"; fi
  fi
fi

# You can create this file in kickstartfile if you know what
# os type it is
if [ "$type" == "$unknown" ]; then
  if [ -f /tmp/RedHat.osbuild ];then
    type="RedHat"
  elif [ -f /tmp/CentOS.osbuild ];then
    type="CentOS"
  fi
fi

# If you still don't know what the type is asssume CentOS
if [ "$type" == "$unknown" ]; then
  type="CentOS"
  echo "Type of OS unknowing; Assuming CentOS"
fi

if [ -z $yum_server ] || [ $yum_server == 'local' ]; then
  uri_header="file:///mnt/source"
  local_header="$uri_header/SIMP/$arch"
else
  uri_header="https://$yum_server/yum/$type/$version/$arch";
  local_header="https://$yum_server/yum/SIMP/$arch";
fi

case $version in
  '8' )
    #setup repo for EL8
    if [ "$type" == 'RedHat' ]; then
    cat << EOF > /tmp/repo-include
repo --name="HighAvailability" --baseurl="$uri_header/HighAvailability" --noverifyssl
repo --name="LoadBalancer" --baseurl="$uri_header/LoadBalancer" --noverifyssl
repo --name="ResilientStorage" --baseurl="$uri_header/ResilientStorage" --noverifyssl
repo --name="ScalableFileSystme" --baseurl="$uri_header/ScalableFileSystem" --noverifyssl
repo --name="Server" --baseurl="$uri_header/Server" --noverifyssl
repo --name="Local" --baseurl="$local_header" --noverifyssl
EOF
   else
     # the dmesg grep above that sets os type is not finding anything.  I am not sure
     # how they determined this or what a good substitute is at thhis time so
     # I just default to CentOS.
     #elif [ "$type" == 'CentOS' ]; then
     cat << EOF > /tmp/repo-include
repo --name="AppStream" --baseurl="$uri_header/AppStream" --noverifyssl
repo --name="BaseOS" --baseurl="$uri_header/BaseOS" --noverifyssl
repo --name="Updates" --baseurl="$uri_header/Updates" --noverifyssl
repo --name="Local" --baseurl="$local_header" --noverifyssl
EOF
    fi
    ;;  
  * )
    #set up repoo for EL7 or EL 6
    if [ "$type" == 'RedHat' ]; then
      cat << EOF > /tmp/repo-include
repo --name="HighAvailability" --baseurl="$uri_header/addons/HighAvailability"
repo --name="ResilientStorage" --baseurl="$uri_header/addons/ResilientStorage"
repo --name="Base" --baseurl="$uri_header"
repo --name="Local" --baseurl="$local_header"
EOF
    elif [ "$type" == 'CentOS' ]; then
      cat << EOF > /tmp/repo-include
repo --name="Server" --baseurl="$uri_header"
repo --name="Local" --baseurl="$local_header"
EOF
    fi
esac
