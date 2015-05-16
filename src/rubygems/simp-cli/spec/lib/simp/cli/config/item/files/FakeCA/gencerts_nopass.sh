#!/bin/sh
# mocked gencerts_nopass.sh
for hosts in `cat togen`; do
  hosts=`echo $hosts | sed -e 's/[ \t]//g'`
  hname=`echo $hosts | cut -d',' -f1`
  keydist="../keydist" # location in testing framework
  mkdir -p "${keydist}/${hname}"
  echo "$hname: dummy generated" >>  ${keydist}/${hname}/${hname}.pub
  cat ${keydist}/${hname}/${hname}.pub >> ${keydist}/${hname}/${hname}.pem
done
