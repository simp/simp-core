#!/bin/sh

# Common functions for gencerts items.

keydist='../modules/pki/files/keydist'
CA_src='/etc/pki/tls/misc/CA'

export CATOP="`pwd`/demoCA"

check_cacerts () {
if [ ! -f cacertkey ]; then
  dd if=/dev/urandom status=none bs=60 count=1 | openssl base64 -e -nopad | tr -d '\n' > cacertkey
  echo '' >> cacertkey
fi
}

create_ca () {
  if [ ! -d demoCA ]; then
    export OPENSSL_CONF=ca.cnf;

    sed -i "s/^\([[:space:]]*commonName_default\).*/\1 \t\t= Fake Org Fake CA - `uuidgen | cut -f1 -d'-'`/" ca.cnf;

    if [ $batch -eq 0 ]; then
      if [ ! -f 'CA_batch' ]; then
        sed -e 's/^REQ=\(.*\) req\(.*\)"/REQ=\1 req \2 -batch -passout file:cacertkey"/' $CA_src | \
          sed -e 's/^CA=\(.*\) ca\(.*\)"/CA=\1 ca \2 -passin file:cacertkey"/' | \
          sed -e 's/read FILE/#read FILE/' > 'CA_batch'

        chmod +x 'CA_batch'
      fi

      CA='./CA_batch'
    else
      if [ ! -f 'CA' ]; then
        sed -e 's/^REQ=\(.*\) req\(.*\)"/REQ=\1 req \2 -passout file:cacertkey"/' $CA_src | \
          sed -e 's/^CA=\(.*\) ca\(.*\)"/CA=\1 ca \2 -passin file:cacertkey"/' > 'CA'

        chmod +x 'CA'
      fi

      CA='./CA'
    fi

    $CA -newca
    wait;
  fi

  if [ ! -d output/conf ]; then
    mkdir -p "output/conf"
  fi

  if [ ! -d working ]; then
    mkdir -p "working"
  fi

  if [ ! -d output/users ]; then
    mkdir -p "output/users"
  fi
}

distribute_ca () {

  cacert="demoCA/cacert.pem";
  hash=`openssl x509 -in $cacert -hash -noout`;
  cacerts="${keydist}/cacerts";

  if [ ! -d $cacerts ]; then
    mkdir -p $cacerts;
  fi

  suffix=0;

  if [ -f $cacerts/$hash.0 ] && [ "`md5sum $cacert | cut -f1 -d' '`" != "`md5sum $cacerts/$hash.0 | cut -f1 -d' '`" ]; then
    echo "Found existing CA cert, preserving....";
    pushd .;
    cd $cacerts;
    suffix=$(( 1 + `ls $hash.* | sort -n | tail -1 | cut -f2 -d'.'` ));
    mv -f cacert.pem $hash.$suffix;
    popd;
  elif [ -f $cacerts/$hash.0 ]; then
    echo "Existing CA cert does not need to be replaced....";
  else
    echo "Copying in new CA cert...."
    ca_id=`grep '^[[:space:]]*commonName_default' ca.cnf | rev | cut -f1 -d' ' | rev`

    cp $cacert $cacerts/cacert_${ca_id}.pem;

    cd $cacerts;
    ln -s cacert_${ca_id}.pem $hash.0;

    cd -;
  fi

  chmod -R u+rwX,g+rX,o-rwx $keydist;
  chown -R root.puppet $keydist;
}
