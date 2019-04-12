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
  python -c 'import sys; import random; import string; sys.stdout.write("".join(random.choice(string.lowercase+string.uppercase+string.digits) for i in range(1024)))' > /boot/disk_creds

  passphrase=`cat /boot/disk_creds`

  echo $DISK > /boot/crypt_disk
fi

# This parses out some command line options generally only used by the
# DVD, but available to PXE clients as well.

simp_opt=`awk -F "simp_opt=" '{print $2}' /proc/cmdline | cut -f1 -d' '`

# This check to see if any of the simp_disk_* parameters are set and if they are it overrides
# the value for that parameter to whatever has been passed in.

if grep -q "simp_disk_swapvol=" /proc/cmdline; then
  simp_disk_swapvol=`awk -F "simp_disk_swapvol=" '{print $2}' /proc/cmdline | cut -f1 -d' '`
else
  simp_disk_swapvol=1024
fi
if grep -q "simp_disk_rootvol=" /proc/cmdline; then
  simp_disk_rootvol=`awk -F "simp_disk_rootvol=" '{print $2}' /proc/cmdline | cut -f1 -d' '`
else
  simp_disk_rootvol=10240
fi
if grep -q "simp_disk_tmpvol=" /proc/cmdline; then
  simp_disk_tmpvol=`awk -F "simp_disk_tmpvol=" '{print $2}' /proc/cmdline | cut -f1 -d' '`
else
  simp_disk_tmpvol=2048
fi
if grep -q "simp_disk_homevol=" /proc/cmdline; then
  simp_disk_homevol=`awk -F "simp_disk_homevol=" '{print $2}' /proc/cmdline | cut -f1 -d' '`
else
  simp_disk_homevol=1024
fi
if grep -q "simp_disk_varvol=" /proc/cmdline; then
  simp_disk_varvol=`awk -F "simp_disk_varvol=" '{print $2}' /proc/cmdline | cut -f1 -d' '`
else
  simp_disk_varvol=1024
fi
if grep -q "simp_disk_varlogvol=" /proc/cmdline; then
  simp_disk_varlogvol=`awk -F "simp_disk_varlogvol=" '{print $2}' /proc/cmdline | cut -f1 -d' '`
else
  simp_disk_varlogvol=4096
fi
if grep -q "simp_disk_varlogauditvol=" /proc/cmdline; then
  simp_disk_varlogauditvol=`awk -F "simp_disk_varlogauditvol=" '{print $2}' /proc/cmdline | cut -f1 -d' '`
else
  simp_disk_varlogauditvol=1024
fi

# This checks to see which disk should grow to fill the rest of the size if any is left over. This defaults
# to grow VarVol.

if grep -q "simp_grow_vol=" /proc/cmdline; then
  simp_grow_vol=`awk -F "simp_grow_vol=" '{print $2}' /proc/cmdline | cut -f1 -d' '`
else
  simp_grow_vol='VarVol'
fi

if [ "$simp_opt" != "prompt" ]; then
  cat << EOF > /tmp/part-include
clearpart --all --initlabel --drives=${DISK}
part /boot/efi --fstype=efi --size=400 --ondisk ${DISK} --asprimary
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
logvol swap --fstype=swap --name=SwapVol --vgname=VolGroup00 --size=${simp_disk_swapvol} `if [[ "$simp_grow_vol" == "SwapVol" ]]; then echo '--grow'; fi`
logvol / --fstype=ext4 --name=RootVol --vgname=VolGroup00 --size=${simp_disk_rootvol} --fsoptions=iversion `if [[ "$simp_grow_vol" == "RootVol" ]]; then echo '--grow'; fi`
logvol /tmp --fstype=ext4 --name=TmpVol --vgname=VolGroup00 --size=${simp_disk_tmpvol} --fsoptions=nosuid,noexec,nodev `if [[ "$simp_grow_vol" == "TmpVol" ]]; then echo '--grow'; fi`
logvol /home --fstype=ext4 --name=HomeVol --vgname=VolGroup00 --size=${simp_disk_homevol} --fsoptions=nosuid,noexec,nodev,iversion `if [[ "$simp_grow_vol" == "HomeVol" ]]; then echo '--grow'; fi`
logvol /var --fstype=ext4 --name=VarVol --vgname=VolGroup00 --size=${simp_disk_varvol} `if [[ "$simp_grow_vol" == "VarVol" ]]; then echo '--grow'; fi`
logvol /var/log --fstype=ext4 --name=VarLogVol --vgname=VolGroup00 --size=${simp_disk_varlogvol} --fsoptions=nosuid,noexec,nodev `if [[ "$simp_grow_vol" == "VarLogVol" ]]; then echo '--grow'; fi`
logvol /var/log/audit --fstype=ext4 --name=VarLogAuditVol --vgname=VolGroup00 --size=${simp_disk_varlogauditvol} --fsoptions=nosuid,noexec,nodev `if [[ "$simp_grow_vol" == "VarLogAuditVol" ]]; then echo '--grow'; fi`
EOF
fi
