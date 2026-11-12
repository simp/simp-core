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
  /sys/block/nvme[0-9]n[0-9] \
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
  cat /dev/random | LC_CTYPE=C tr -dc "[:alnum:]" | head -c 256 > /boot/disk_creds
  passphrase=`cat /boot/disk_creds`

  echo $DISK > /boot/crypt_disk
fi

# This parses out some command line options generally only used by the
# DVD, but available to PXE clients as well.

simp_opt=`awk -F "simp_opt=" '{print $2}' /proc/cmdline | cut -f1 -d' '`

if [ "$simp_opt" == "prompt" ]; then
  # This is the recommended workaround for a RedHat bug (BZ#1954408) where
  # the installation program attempts to perform automatic partitioning, even
  # when you do not specify any partitioning commands in the kickstart file.
  # https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/8.4_release_notes/known-issues#known-issue_installer-and-image-creation
  # This will cause the "Installation Destination" icon to show an "Kickstart
  # insufficient" error, which, in turn, will force the user to partition the
  # disks manually.
  echo "reqpart" > /tmp/part-include
else
  cat << EOF > /tmp/part-include
clearpart --all --initlabel --drives=${DISK}
part /boot --fstype=ext4 --size=1024 --ondisk ${DISK} --asprimary --fsoptions=nosuid,nodev
part /boot/efi --fstype=efi --size=400 --ondisk ${DISK} --asprimary
EOF

# In EL8 (8.2) the partitioning fails if --encrypted  is used and the size=1.
# The size was set to equal the sum of all the logical partitions (20G) to prevent this.
# You can probably use a smaller size but we have not, at this time, determined how
# small the initial size of the partion can to be to prevent the error.

  if [ $encrypt -eq 0 ]; then
    echo "part pv.01 --size=20480 --grow --ondisk ${DISK} --encrypted --passphrase=${passphrase}" >> /tmp/part-include
  else
    echo "part pv.01 --size=1 --grow --ondisk ${DISK}" >> /tmp/part-include
  fi
fi

if [ "$simp_opt" != "prompt" ]; then
  cat << EOF >> /tmp/part-include
volgroup VolGroup00 pv.01
logvol swap --fstype=swap --name=SwapVol --vgname=VolGroup00 --size=1024
logvol / --fstype=ext4 --name=RootVol --vgname=VolGroup00 --size=10240 --fsoptions=iversion
logvol /tmp --fstype=ext4 --name=TmpVol --vgname=VolGroup00 --size=2048 --fsoptions=nosuid,noexec,nodev
logvol /home --fstype=ext4 --name=HomeVol --vgname=VolGroup00 --size=1024 --fsoptions=nosuid,noexec,nodev,iversion
logvol /var --fstype=ext4 --name=VarVol --vgname=VolGroup00 --size=1024 --grow
logvol /var/log --fstype=ext4 --name=VarLogVol --vgname=VolGroup00 --size=4096 --fsoptions=nosuid,noexec,nodev
logvol /var/log/audit --fstype=ext4 --name=VarLogAuditVol --vgname=VolGroup00 --size=1024 --fsoptions=nosuid,noexec,nodev
EOF
fi
