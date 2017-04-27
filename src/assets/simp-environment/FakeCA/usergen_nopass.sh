#!/bin/sh

source `dirname $0`/gencerts_common.sh;

check_cacerts;

batch=1;
if [ "$1" == "auto" ]; then
  batch=0;
fi

create_ca;

outdir="output/users";

if [ ! -f usergen ]; then
  echo "Could not find file 'usergen' containing users to generate"
  exit 1;
fi

# Store stdin for use inside the loop
exec 3>&0

overwrite=0;
cat usergen | while read line; do
  line=`echo $line | sed -e 's/^[[:space:]]+//' | sed -e 's/[[:space:]]+$//'`;
  user=`echo $line | sed -e 's/[[:space:]]+/ /g' | cut -d' ' -f1`;
  email=`echo $line | sed -e 's/[[:space:]]+/ /g' | cut -d' ' -f2`;

  if [ "$email" == "$user" ]; then
    email="$email@`hostname -d`"
  fi

  echo
  echo "Processing $user"

  if [ -d $outdir/$user ]; then
    sed -e "s/#USERNAME#/$user/" user.cnf > output/conf/$user.cnf;
    sed -i "s/#EMAIL#/$email/" output/conf/$user.cnf;

    if [ $overwrite -eq 0 ]; then
      echo "Warning: Directory $user exists"
      echo "Do you want to overwrite this user's keys? [y|N|a]"

      read -u 3 choice

      case $choice in
        [Yy]*)
          echo "Overwriting $user's keys";
          ;;
        [aA]*)
          echo "Defaulting to overwrite";
          overwrite=1;
          ;;
        *)
          echo "Skipping $user";
          continue;
          ;;
      esac
    fi
  else
    echo "running mkdir $outdir/$user"
    mkdir -p $outdir/$user;
    sed -e "s/#USERNAME#/$user/" user.cnf > output/conf/$user.cnf;
    sed -i "s/#EMAIL#/$email/" output/conf/$user.cnf;
  fi

  # Revoke any existing certs.
  for cert in `find demoCA/newcerts -type f` `find demoCA/certs -type f`; do
    if [ "$email" == "`openssl x509 -subject -noout -in $cert | rev | cut -f1 -d'=' | rev`" ]; then
      echo "Found existing certificate for $hname, revoking!"

      if [ ! -d demoCA/revoked ]; then
        mkdir demoCA/revoked;
      fi

      OPENSSL_CONF=ca.cnf openssl ca -passin file:cacertkey -revoke $cert -crl_reason superseded
      mv $cert demoCA/revoked;
    fi

  done

  export OPENSSL_CONF=output/conf/$user.cnf;

  echo "running openssl req"
  openssl req -new -nodes -keyout $outdir/$user/$user.pem -out working/"$user"req.pem -days 360 -batch;
  echo "running openssl ca"
  openssl ca -passin file:cacertkey -batch -out $outdir/$user/$user.pub -infiles working/"$user"req.pem

  cat $outdir/$user/$user.pub >> $outdir/$user/$user.pem

  echo "User $user's keys can be found in $outdir/$user";
done
