
#!/bin/sh
#
# Usage: repodetect.sh <Version> <yum_server>
#
# Version: Mandatory
# Yum_server:
# - Blank or 'Local' -> use a local file source
# - Anything else    -> use this is the URI at which to point.

unknown="REPODETECT_UNKNOWN_OS_TYPE"
type=$unknown
osline=`dmesg -s 10485760 | grep '(Kernel Module GPG key)'`

version=$1
yum_server=$2

if [ -z $version ]; then
  echo "Error: You must pass <version> as the first argument";
  exit 1;
fi

arch="i386"
if [ `uname -m` == "x86_64" ]; then arch="x86_64"; fi

echo $osline | grep -q 'Red Hat, Inc.'
if [ $? == 0 ]; then
  type="RedHat"
else
  echo $osline | grep -q 'CentOS'
  if [ $? == 0 ]; then type="CentOS"; fi
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

if [ -z $yum_server ] || [ $yum_server == 'local' ]; then
  uri_header="file:///mnt/source"
  local_header="$uri_header/SIMP/$arch"
else
  uri_header="http://$yum_server/yum/$type/$version/$arch";
  local_header="http://$yum_server/yum/SIMP/$arch";
fi

if [ "$type" == 'RedHat' ]; then
  cat << EOF > /tmp/repo-include
repo --name="HighAvailability" --baseurl="$uri_header/HighAvailability"
repo --name="LoadBalancer" --baseurl="$uri_header/LoadBalancer"
repo --name="ResilientStorage" --baseurl="$uri_header/ResilientStorage"
repo --name="ScalableFileSystme" --baseurl="$uri_header/ScalableFileSystem"
repo --name="Server" --baseurl="$uri_header/Server"
repo --name="Local" --baseurl="$local_header"
EOF
elif [ "$type" == 'CentOS' ]; then
  cat << EOF > /tmp/repo-include
repo --name="Server" --baseurl="$uri_header"
repo --name="Local" --baseurl="$local_header"
EOF
fi
