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

# This parses out some command line options generally only used by the
# DVD, but available to PXE clients as well.

simp_opt=`awk -F "simp_opt=" '{print $2}' /proc/cmdline | cut -f1 -d' '`

if [ "$simp_opt" != "prompt" ]; then
  cat << EOF > /tmp/part-include
clearpart --all --initlabel --drives=${DISK}
part /boot --fstype ext4 --size=1024 --ondisk ${DISK} --asprimary --fsoptions=nosuid,nodev
part pv.01 --size=1 --grow --ondisk ${DISK}
volgroup VolGroup00 pv.01
logvol swap --fstype swap --name=SwapVol --vgname=VolGroup00 --size=1024
logvol / --fstype ext4 --name=RootVol --vgname=VolGroup00 --size=4096
logvol /tmp --fstype ext4 --name=TmpVol --vgname=VolGroup00 --size=2048 --fsoptions=nosuid,noexec,nodev
logvol /home --fstype ext4 --name=HomeVol --vgname=VolGroup00 --size=1024 --fsoptions=nosuid,noexec,nodev
logvol /var/log --fstype ext4 --name=VarLogVol --vgname=VolGroup00 --size=4096 --fsoptions=nosuid,noexec,nodev
logvol /var/log/audit --fstype ext4 --name=VarLogAuditVol --vgname=VolGroup00 --size=1024 --fsoptions=nosuid,noexec,nodev
EOF

  if [ "$simp_opt" == "bigvar" ]; then
    echo "logvol /srv --fstype ext4 --name=SrvVol --vgname=VolGroup00 --size=3072 --fsoptions=nosuid,nodev" >> /tmp/part-include
    echo "logvol /var --fstype ext4 --name=VarVol --vgname=VolGroup00 --size=1024 --grow" >> /tmp/part-include
  else
    echo "logvol /srv --fstype ext4 --name=SrvVol --vgname=VolGroup00 --size=1024 --grow --fsoptions=nosuid,nodev" >> /tmp/part-include
    echo "logvol /var --fstype ext4 --name=VarVol --vgname=VolGroup00 --size=3072" >> /tmp/part-include
  fi

fi
