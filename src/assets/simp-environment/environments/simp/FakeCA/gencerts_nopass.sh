#!/bin/sh

source `dirname $0`/gencerts_common.sh;

check_cacerts;

batch=1;
if [ "$1" == "auto" ]; then
  batch=0;
fi

create_ca;

for hosts in `cat togen`; do
  hosts=`echo $hosts | sed -e 's/[ \t]//g'`
  hname=`echo $hosts | cut -d',' -f1`
  if [ "$hname" != "$hosts" ];
  then
    alts=`echo $hosts | cut -d',' -f2-`
    altnames=''
    for i in `echo $alts | tr ',' '\n'`
    do
      ruby -r ipaddr -e "begin IPAddr.new('$i') rescue exit 1 end"
      if [ $? -eq 0 ]; then
        # This is required due to some applications not properly supporting the
        # IP version of subjectAltName.
        prefixes='IP DNS';
      else
        prefixes='DNS';
      fi

      for prefix in $prefixes; do
        if [ "$altnames" != ''  ];
        then
          altnames+=",$prefix:$i";
        else
          altnames+="$prefix:$i";
        fi;
      done
    done

    echo "processing $hname"
    sed -e "s/#HOSTNAME#/$hname/" -e "s/#ALTNAMES#/$altnames/" default_altnames.cnf > output/conf/$hname.cnf;
  else
    echo "processing $hname"
    sed -e "s/#HOSTNAME#/$hname/" default.cnf > output/conf/$hname.cnf;
  fi

  # Revoke any existing certs.
  for cert in `find demoCA/newcerts -type f` `find demoCA/certs -type f`; do
    if [ "$hname" == "`openssl x509 -subject -noout -in $cert | rev | cut -f1 -d'=' | rev`" ]; then
      echo "Found existing certificate for $hname, revoking!"

      if [ ! -d demoCA/revoked ]; then
        mkdir demoCA/revoked;
      fi

      OPENSSL_CONF=ca.cnf openssl ca -passin file:cacertkey -revoke $cert -crl_reason superseded
      mv $cert demoCA/revoked;
    fi

  done

  export OPENSSL_CONF=output/conf/$hname.cnf;

  echo "running mkdir ${keydist}/${hname}"
  if [ -d "${keydist}/${hname}" ]; then
    echo "directory $hname exists"
  else
    mkdir -p "${keydist}/${hname}/cacerts"
  fi

  echo "running openssl req"
  openssl req -new -nodes -keyout ${keydist}/${hname}/${hname}.pem -out working/"${hname}"req.pem -days 360 -batch;
  echo "running openssl ca"
  openssl ca -passin file:cacertkey -batch -out ${keydist}/${hname}/${hname}.pub -infiles working/"${hname}"req.pem

  cat ${keydist}/${hname}/${hname}.pub >> ${keydist}/${hname}/${hname}.pem

done

distribute_ca;
