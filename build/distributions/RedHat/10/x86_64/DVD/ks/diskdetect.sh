#!/bin/sh
#
# diskdetect.sh - write the kickstart partitioning for the first disk
#
# Writes /tmp/part-include.
#
# Installer (kernel command line) options:
#
#   simp_disk_crypt   Encrypt the LVM physical volume.  The key is stored
#                     unencrypted in /etc/.cryptcreds and added to the
#                     initramfs, so the system boots unattended.  This is *not*
#                     secure; it lets you change the passphrase later without
#                     reinstalling.
#   simp_opt=prompt   Partition the disk by hand in the installer.  Encrypt
#                     it there too; simp_disk_crypt is ignored.
#
# Exits with an error when it can't find a disk to install on.
#

DISK=""

for disk in \
  /sys/block/sd[a-z] \
  /sys/block/sd[a-z][a-z] \
  /sys/block/xvd[a-z] \
  /sys/block/xvd[a-z][a-z] \
  /sys/block/vd[a-z] \
  /sys/block/vd[a-z][a-z] \
  /sys/block/nvme[0-9]n[0-9] \
  /sys/block/nvme[0-9]n[0-9][0-9] \
  /sys/block/nvme[0-9][0-9]n[0-9] \
  /sys/block/nvme[0-9][0-9]n[0-9][0-9] \
  /sys/block/mmcblk[0-9] \
  /sys/block/mmcblk[0-9][0-9] \
  ;
do
  [ -d "$disk" ] || continue

  # Ignore hidden (e.g. NVMe multipath paths), removable and virtual devices.

  if [ -f "$disk"/hidden ]; then
    if read -r hidden _ < "$disk"/hidden; then
      [ "$hidden" != "0" ] && continue
    fi
  fi

  if [ -f "$disk"/removable ]; then
    if read -r removable _ < "$disk"/removable; then
      [ "$removable" != "0" ] && continue
    fi
  fi

  if [ -f "$disk"/device/vendor ] && [ -f "$disk"/device/model ]; then
    if read -r vendor _ < "$disk"/device/vendor && \
       read -r model _ < "$disk"/device/model; then
      [ "$vendor" != "VMware" ] && [ "$model" = "Virtual" ] && continue
    fi
  fi

  # Found the first disk.
  DISK="$(basename "$disk")"
  break
done

: > /tmp/part-include

if grep -qE '(^| )simp_(disk_crypt|crypt_disk)( |=|$)' /proc/cmdline; then
  encrypt=0
else
  encrypt=1
fi

simp_opt="$(awk -F 'simp_opt=' '{print $2}' /proc/cmdline | cut -f1 -d' ')"

if [ "$simp_opt" = "prompt" ]; then
  # Work around BZ#1954408: anaconda partitions automatically when a kickstart
  # has no partitioning commands.  `reqpart` alone leaves "Installation
  # Destination" incomplete, so the user has to partition by hand.
  echo "reqpart" > /tmp/part-include
  if [ $encrypt -eq 0 ]; then
    echo "WARNING: simp_disk_crypt is ignored with simp_opt=prompt; encrypt the disk in the installer" >&2
  fi
  exit 0
fi

if [ -z "$DISK" ]; then
  echo "ERROR: diskdetect.sh found no disk to install on (looked for non-removable sd*, vd*, xvd*, nvme* and mmcblk* disks in /sys/block).  Boot with simp_opt=prompt to partition by hand." >&2
  exit 1
fi

if [ $encrypt -eq 0 ]; then
  # anaconda doesn't create /boot until it partitions the disk
  mkdir -p /boot
  LC_CTYPE=C tr -dc '[:alnum:]' < /dev/urandom | head -c 256 > /boot/disk_creds
  passphrase="$(cat /boot/disk_creds)"

  echo "$DISK" > /boot/crypt_disk
fi

# `reqpart` adds whatever the firmware needs: /boot/efi on UEFI, or a BIOS
# boot partition on BIOS with a GPT label.
cat << EOF > /tmp/part-include
zerombr
clearpart --all --initlabel --drives=${DISK}
ignoredisk --only-use=${DISK}
reqpart
part /boot --fstype=ext4 --size=1024 --ondisk=${DISK} --fsoptions=nosuid,nodev
EOF

# Partitioning fails if an encrypted PV is created with --size=1, so it starts
# at the sum of the logical volumes below.
if [ $encrypt -eq 0 ]; then
  echo "part pv.01 --size=20480 --grow --ondisk=${DISK} --encrypted --passphrase=${passphrase}" >> /tmp/part-include
else
  echo "part pv.01 --size=1 --grow --ondisk=${DISK}" >> /tmp/part-include
fi

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
