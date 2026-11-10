#!/bin/bash
#
# Kickstart a libvirt VM with one of the SIMP kickstarts, the way a SIMP PXE
# server would, then boot the installed host and check it.
#
# Usage: run_install.sh -v VERSION -r ROLE [-f FIRMWARE] [-F] [-o OUTDIR]
#
#   -v VERSION   EL major version: 8, 9 or 10
#   -r ROLE      'client' (pupclient_x86_64.cfg) or 'server'
#                (simp_server_x86_64.cfg)
#   -f FIRMWARE  'uefi' (default) or 'bios'
#   -F           Install in FIPS mode (fips=1 on the installer command line)
#   -C           Encrypt the disk (simp_disk_crypt on the installer command
#                line).  The installed host must then boot unattended.
#   -o OUTDIR    Where to put the disk image and logs (default: a new
#                directory under /var/tmp)
#
# Needs root, libvirt with an active 'default' network, virt-install,
# python3, openssl, and guestfish.  The OS comes from the AlmaLinux mirrors,
# and EPEL and OpenVox from their public repositories (see
# ks_test_server.py).
#
# Environment:
#
#   INSTALL_TIMEOUT  Minutes to wait for the installation (default: 60)
#   BOOT_TIMEOUT     Seconds to wait for the installed host to boot
#                    (default: 600)
#   KEEP_VM          Set to 'yes' to keep the VM and disk image afterwards
#   KS_PORT          Port for the test kickstart/yum server (default: 8443)

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"

version=''
role=''
firmware='uefi'
fips=0
crypt=''
outdir=''

while getopts 'v:r:f:FCo:' opt; do
  case "$opt" in
    v) version="$OPTARG" ;;
    r) role="$OPTARG" ;;
    f) firmware="$OPTARG" ;;
    F) fips=1 ;;
    C) crypt=' simp_disk_crypt' ;;
    o) outdir="$OPTARG" ;;
    *) sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; exit 2 ;;
  esac
done

case "$version" in 8|9|10) ;; *) echo "ERROR: -v must be 8, 9 or 10" >&2; exit 2 ;; esac
case "$role" in
  client) ks_file='pupclient_x86_64.cfg' ;;
  server) ks_file='simp_server_x86_64.cfg' ;;
  *) echo "ERROR: -r must be 'client' or 'server'" >&2; exit 2 ;;
esac
case "$firmware" in uefi|bios) ;; *) echo "ERROR: -f must be 'uefi' or 'bios'" >&2; exit 2 ;; esac

install_timeout="${INSTALL_TIMEOUT:-60}"
boot_timeout="${BOOT_TIMEOUT:-600}"
os_mirror='https://repo.almalinux.org/almalinux'
ks_dir="${repo_root}/build/distributions/RedHat/${version}/x86_64/DVD/ks"
name="simp-ks-el${version}-${role}-${firmware}${crypt:+-crypt}"
port="${KS_PORT:-8443}"

[ -f "${ks_dir}/${ks_file}" ] || { echo "ERROR: ${ks_dir}/${ks_file} not found" >&2; exit 1; }

if [ -z "$outdir" ]; then
  outdir="$(mktemp -d "/var/tmp/${name}.XXXXXX")"
fi
mkdir -p "$outdir"
outdir="$(cd "$outdir" && pwd)"
chmod 0755 "$outdir"

log() { echo "[$(date -u +%H:%M:%S)] $*"; }

server_pid=''
cleanup() {
  local rc=$?
  set +e
  [ -n "$server_pid" ] && kill "$server_pid" 2>/dev/null
  if [ "${KEEP_VM:-no}" != 'yes' ]; then
    virsh destroy "$name" >/dev/null 2>&1
    virsh undefine "$name" --nvram >/dev/null 2>&1
    rm -f "${outdir}/disk.qcow2"
  fi
  exit $rc
}
trap cleanup EXIT

host_ip="$(virsh net-dumpxml default | sed -n "s/.*<ip address='\([0-9.]*\)'.*/\1/p" | head -1)"
[ -n "$host_ip" ] || { echo "ERROR: Could not find the libvirt 'default' network address" >&2; exit 1; }

# A firewalld host (e.g. a Fedora workstation) blocks guests from reaching the
# test server; GitHub's Ubuntu runners don't run firewalld.
if command -v firewall-cmd >/dev/null && firewall-cmd --state >/dev/null 2>&1; then
  firewall-cmd --zone=libvirt --add-port="${port}/tcp" >/dev/null
fi

log "Generating test credentials"
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj "/CN=${host_ip}" \
  -keyout "${outdir}/server.key" -out "${outdir}/server.crt" 2>/dev/null
root_pass_hash="$(openssl passwd -6 "$(openssl rand -hex 16)")"
boot_pass_hash="$(python3 -I -c '
import hashlib, os
salt = os.urandom(64)
digest = hashlib.pbkdf2_hmac("sha512", os.urandom(16), salt, 10000, 64)
print("grub.pbkdf2.sha512.10000.%s.%s" % (salt.hex().upper(), digest.hex().upper()))
')"

log "Starting the kickstart/yum test server on https://${host_ip}:${port}/"
python3 -I "${script_dir}/ks_test_server.py" \
  --listen "$host_ip" --port "$port" \
  --cert "${outdir}/server.crt" --key "${outdir}/server.key" \
  --ks-dir "$ks_dir" --extra-dir "${script_dir}/files" \
  --set "KSSERVER=${host_ip}:${port}" \
  --set "YUMSERVER=${host_ip}:${port}" \
  --set "LINUXDIST=AlmaLinux" \
  --set "ROOTPASS=${root_pass_hash}" \
  --set "BOOTPASS=${boot_pass_hash}" \
  > "${outdir}/ks_test_server.log" 2>&1 &
server_pid=$!

for _ in $(seq 1 30); do
  curl -kfsS -o /dev/null "https://${host_ip}:${port}/ks/${ks_file}" 2>/dev/null && break
  sleep 1
done
curl -kfsS -o "${outdir}/${ks_file}" "https://${host_ip}:${port}/ks/${ks_file}"

# Boot the installer's kernel and initrd directly, with the arguments a SIMP
# PXE server passes (see pupmod-simp-tftpboot), the way PXE boot does.
log "Downloading the EL${version} installer kernel and initrd"
curl -fsSL -o "${outdir}/vmlinuz" "${os_mirror}/${version}/BaseOS/x86_64/os/images/pxeboot/vmlinuz"
curl -fsSL -o "${outdir}/initrd.img" "${os_mirror}/${version}/BaseOS/x86_64/os/images/pxeboot/initrd.img"

kernel_args="inst.ks=https://${host_ip}:${port}/ks/${ks_file} inst.noverifyssl fips=${fips} inst.text console=ttyS0,115200${crypt}"

boot_opts=()
if [ "$firmware" = 'uefi' ]; then
  boot_opts=(--boot uefi)
fi

virsh destroy "$name" >/dev/null 2>&1 || :
virsh undefine "$name" --nvram >/dev/null 2>&1 || :
# virtlogd writes the serial console logs here.
consoledir="${outdir}/console"
rm -rf "${outdir}/disk.qcow2" "$consoledir"
mkdir "$consoledir"
if command -v selinuxenabled >/dev/null && selinuxenabled; then
  chcon -t virt_log_t "$consoledir"
fi

log "Installing ${name} (timeout: ${install_timeout} minutes)"
log "Installer console: ${outdir}/install-ttyS0.log"
install_rc=0
virt-install \
  --name "$name" \
  --memory 4096 \
  --vcpus 2 \
  --cpu host-passthrough \
  --osinfo detect=off,name=linux2022 \
  --disk "path=${outdir}/disk.qcow2,size=30,format=qcow2,bus=virtio" \
  --check disk_size=off \
  --network network=default,model=virtio \
  "${boot_opts[@]}" \
  --install "kernel=${outdir}/vmlinuz,initrd=${outdir}/initrd.img,kernel_args=${kernel_args},kernel_args_overwrite=yes" \
  --graphics none \
  --serial "file,path=${consoledir}/ttyS0.log" \
  --serial "file,path=${consoledir}/ttyS1.log" \
  --noautoconsole \
  --noreboot \
  --wait "$install_timeout" || install_rc=$?

cp "${consoledir}/ttyS0.log" "${outdir}/install-ttyS0.log" 2>/dev/null || :

if [ $install_rc -ne 0 ]; then
  log "ERROR: The installation did not finish (virt-install exit code ${install_rc})"
  tail -n 60 "${outdir}/install-ttyS0.log" 2>/dev/null | sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g' || :
  exit 1
fi

if grep -qE 'An error occurred|Traceback|Pane is dead' "${outdir}/install-ttyS0.log"; then
  log "ERROR: The installer reported an error"
  tail -n 60 "${outdir}/install-ttyS0.log" | sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g'
  exit 1
fi

# The installed host's kernel console is ttyS1 (see the kickstart's
# `bootloader --append`), so the boot and login prompt show up there.
log "Booting the installed host (timeout: ${boot_timeout} seconds)"
log "Host console: ${outdir}/boot-ttyS1.log"
virsh start "$name" >/dev/null
booted=no
for _ in $(seq 1 "$((boot_timeout / 5))"); do
  if grep -q 'login:' "${consoledir}/ttyS1.log" 2>/dev/null; then
    booted=yes
    break
  fi
  sleep 5
done
# Give first-boot services (the SIMP client bootstrap) a moment to finish.
[ "$booted" = yes ] && sleep 30
cp "${consoledir}/ttyS1.log" "${outdir}/boot-ttyS1.log" 2>/dev/null || :
virsh shutdown "$name" >/dev/null 2>&1 || :
for _ in $(seq 1 60); do
  [ "$(virsh domstate "$name" 2>/dev/null)" = 'shut off' ] && break
  sleep 2
done
virsh destroy "$name" >/dev/null 2>&1 || :

if [ "$booted" != yes ]; then
  log "ERROR: The installed host did not reach a login prompt"
  tail -n 60 "${outdir}/boot-ttyS1.log" 2>/dev/null || :
  exit 1
fi

log "Inspecting the installed host"
export LIBGUESTFS_BACKEND=direct
if [ -n "$crypt" ]; then
  # The key is only on the encrypted host, so all that can be checked from
  # here is that the disk is encrypted.  Booting to a login prompt above
  # showed that the host unlocks it unattended.
  partitions="$(guestfish --ro -a "${outdir}/disk.qcow2" run : list-partitions)"
  {
    echo 'run'
    for partition in $partitions; do
      echo "-echo ${partition}"
      echo "-vfs-type ${partition}"
    done
  } | guestfish --ro -a "${outdir}/disk.qcow2" > "${outdir}/inspect.txt" 2>&1 || :
  cat "${outdir}/inspect.txt"
  if grep -q 'crypto_LUKS' "${outdir}/inspect.txt"; then
    log "PASS: the disk is encrypted, and the host boots unattended"
    log "All checks passed"
    exit 0
  fi
  log "FAIL: the disk is not encrypted"
  exit 1
fi

guestfish --ro -a "${outdir}/disk.qcow2" -i <<'EOF' > "${outdir}/inspect.txt" 2>&1 || :
-sh "rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE}\n' openvox-agent openvox-server simp simp-adapter || :"
-sh "echo fips_kernel_arg=$(grep -o 'fips=[01]' /etc/kernel/cmdline /boot/loader/entries/*.conf /etc/default/grub 2>/dev/null | sort -u | tr '\n' ' ')"
-sh "echo crypto_policy=$(cat /etc/crypto-policies/config 2>/dev/null)"
-sh "echo selinux=$(sed -n 's/^SELINUX=//p' /etc/selinux/config)"
-sh "echo bootstrap_test=$(cat /root/simp_client_bootstrap_test 2>/dev/null)"
-sh "echo simp_not_installed=$(test -f /root/SIMP_NOT_INSTALLED && echo yes || echo no)"
-sh "echo openvox_version=$(/opt/puppetlabs/bin/puppet --version 2>/dev/null)"
-cat /root/ks-post.log
EOF
cat "${outdir}/inspect.txt"

failures=()
check() {
  local desc="$1" pattern="$2"
  if grep -qE "$pattern" "${outdir}/inspect.txt"; then
    log "PASS: ${desc}"
  else
    log "FAIL: ${desc}"
    failures+=("$desc")
  fi
}

check 'openvox-agent 9 is installed' '^openvox-agent-9\.'
check 'the OpenVox agent runs' '^openvox_version=9\.'
check 'SELinux is enforcing' '^selinux=enforcing'
if [ "$role" = 'server' ]; then
  check 'openvox-server 9 is installed' '^openvox-server-9\.'
  check 'the missing SIMP repository is recorded' '^simp_not_installed=yes'
else
  check 'the SIMP client bootstrap ran on first boot' '^bootstrap_test=SIMP client bootstrap stand-in ran'
fi
if [ "$fips" = 1 ]; then
  check 'FIPS mode is configured' '^crypto_policy=FIPS'
  if grep -q 'Command line:.* fips=1' "${outdir}/boot-ttyS1.log"; then
    log "PASS: the host booted with fips=1"
  else
    log "FAIL: the host booted with fips=1"
    failures+=('the host booted with fips=1')
  fi
fi

if [ ${#failures[@]} -gt 0 ]; then
  log "${#failures[@]} check(s) failed"
  exit 1
fi
log "All checks passed"
