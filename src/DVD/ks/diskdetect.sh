#!/bin/sh

DISK=""

for disk in \
  /sys/block/sd[a-z] \
  /sys/block/sd[a-z][a-z] \
  /sys/block/cciss!c[0-9]d[0-9] \
  /sys/block/cciss!c[0-9]d[0-9][0-9] \
  /sys/block/cciss!c[0-9][0-9]d[0-9] \
  /sys/block/cciss!c[0-9][0-9]d[0-9][0-9] \
  /sys/block/xvd[a-z] \
  /sys/block/xvd[a-z][a-z] \
  /sys/block/vd[a-z] \
  /sys/block/vd[a-z][a-z] \
  /sys/block/hd[a-z] \
  ;
do
  [ -d "$disk" ] || continue

  # Ignore removable and virtual devices.

  if [ -f "$disk"/removable ]; then
    if read removable junk < "$disk"/removable; then
      [ "$removable" != "0" ] && continue
    fi
  fi

  if [ -f "$disk"/device/vendor -a -f "$disk"/device/model ]; then
    if read vendor junk < "$disk"/device/vendor && \
       read model junk < "$disk"/device/model; then
      [ "$vendor" != "VMware" -a "$model" = "Virtual" ] && continue
    fi
  fi

  # Found the first disk.

  # Convert cciss!c0d0 to cciss/c0d0
  DISK="`basename $disk | sed 's@!@/@g'`"
  break
done

touch /tmp/part-include

# To automatically decrypt your system, the cryptfile needs to be located in an
# unencrypted portion of the system. This is *not* secure but does allow users
# to go in later and change the password without needing to reformat their
# systems.

# For EL6
if [ ! -d /boot ]; then
  mkdir /boot
fi

grep -q simp_disk_crypt /proc/cmdline || grep -q simp_crypt_disk /proc/cmdline
encrypt=$?

if [ $encrypt -eq 0 ]; then
  python -c 'import sys; import random; import string; sys.stdout.write("".join(random.choice(string.lowercase+string.uppercase+string.digits) for i in range(1024)))' > /boot/disk_creds

  passphrase=`cat /boot/disk_creds`

  echo $DISK > /boot/crypt_disk
fi

# This parses out some command line options generally only used by the
# DVD, but available to PXE clients as well.

simp_opt=`awk -F "simp_opt=" '{print $2}' /proc/cmdline | cut -f1 -d' '`

if [ "$simp_opt" != "prompt" ]; then
  cat << EOF > /tmp/part-include
clearpart --all --initlabel --drives=${DISK}
part /boot/efi --fstype=efi --size=200 --ondisk ${DISK} --asprimary
part /boot --fstype=ext4 --size=1024 --ondisk ${DISK} --asprimary --fsoptions=nosuid,nodev
EOF

  if [ $encrypt -eq 0 ]; then
    echo "part pv.01 --size=1 --grow --ondisk ${DISK} --encrypted --cipher=aes-cbc-essiv:sha256 --passphrase=${passphrase}" >> /tmp/part-include
  else
    echo "part pv.01 --size=1 --grow --ondisk ${DISK}" >> /tmp/part-include
  fi
fi

if [ "$simp_opt" != "prompt" ]; then
  cat << EOF >> /tmp/part-include
volgroup VolGroup00 pv.01
logvol swap --fstype=swap --name=SwapVol --vgname=VolGroup00 --size=1024
logvol / --fstype=xfs --name=RootVol --vgname=VolGroup00 --size=4096 --fsoptions=iversion
logvol /tmp --fstype=xfs --name=TmpVol --vgname=VolGroup00 --size=2048 --fsoptions=nosuid,noexec,nodev
logvol /home --fstype=xfs --name=HomeVol --vgname=VolGroup00 --size=1024 --fsoptions=nosuid,noexec,nodev,iversion
logvol /var/log --fstype=xfs --name=VarLogVol --vgname=VolGroup00 --size=4096 --fsoptions=nosuid,noexec,nodev
logvol /var/log/audit --fstype=xfs --name=VarLogAuditVol --vgname=VolGroup00 --size=1024 --fsoptions=nosuid,noexec,nodev
EOF

  if [ "$simp_opt" == "bigsrv" ]; then
    echo "logvol /srv --fstype=xfs --name=SrvVol --vgname=VolGroup00 --size=1024 --fsoptions=nosuid,nodev,iversion --grow" >> /tmp/part-include
    echo "logvol /var --fstype=xfs --name=VarVol --vgname=VolGroup00 --size=4096" >> /tmp/part-include
  else
    echo "logvol /srv --fstype=xfs --name=SrvVol --vgname=VolGroup00 --size=4096 --fsoptions=nosuid,nodev,iversion" >> /tmp/part-include
    echo "logvol /var --fstype=xfs --name=VarVol --vgname=VolGroup00 --size=1024 --grow" >> /tmp/part-include
  fi
fi
