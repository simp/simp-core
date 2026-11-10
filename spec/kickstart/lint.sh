#!/bin/bash
#
# Lint the EL kickstarts.
#
# Usage: lint.sh [KSVALIDATOR]
#
# - Validates each .cfg file with pykickstart's ksvalidator, for its EL
#   version, after replacing the #PLACEHOLDERS# (a '#' starts a comment).
# - Runs ShellCheck on the helper scripts, if it's installed.
# - Checks that diskdetect.sh and repodetect.sh are the same for every EL
#   version, since they support all of them.

set -euo pipefail

ksvalidator="${1:-ksvalidator}"
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

versions=(8 9 10)
rc=0

for version in "${versions[@]}"; do
  ks_dir="${repo_root}/build/distributions/RedHat/${version}/x86_64/DVD/ks"
  for cfg in "$ks_dir"/*.cfg; do
    name="EL${version}/$(basename "$cfg")"
    # shellcheck disable=SC2016 # a literal password hash
    sed \
      -e 's/#ROOTPASS#/$6$salt$hash/' \
      -e 's/#BOOTPASS#/grub.pbkdf2.sha512.10000.00.00/' \
      -e 's/#[A-Z]\{1,\}#/placeholder/g' \
      "$cfg" > "${tmp}/ks.cfg"

    if grep -qE '#[A-Z]+#' "${tmp}/ks.cfg"; then
      echo "FAIL: ${name}: unreplaced placeholder"
      rc=1
    fi

    if out="$("$ksvalidator" -e -v "RHEL${version}" "${tmp}/ks.cfg" 2>&1)"; then
      echo "ok:   ${name}"
    else
      echo "FAIL: ${name}"
      printf '      %s\n' "$out"
      rc=1
    fi

    # The %pre section must pass this file's EL version to repodetect.sh.
    if ! grep -qE "repodetect\.sh '${version}'" "$cfg"; then
      echo "FAIL: ${name}: does not run repodetect.sh for EL${version}"
      rc=1
    fi
    if grep -E '^url ' "$cfg" | grep -qvE "/${version}/x86_64( |$)"; then
      echo "FAIL: ${name}: the 'url' is not for EL${version}"
      rc=1
    fi
  done
done

for script in diskdetect.sh repodetect.sh; do
  reference="${repo_root}/build/distributions/RedHat/${versions[0]}/x86_64/DVD/ks/${script}"
  for version in "${versions[@]:1}"; do
    other="${repo_root}/build/distributions/RedHat/${version}/x86_64/DVD/ks/${script}"
    if ! cmp -s "$reference" "$other"; then
      echo "FAIL: ${script} differs between EL${versions[0]} and EL${version}"
      rc=1
    fi
  done

  if command -v shellcheck >/dev/null; then
    if shellcheck -s sh "$reference"; then
      echo "ok:   shellcheck ${script}"
    else
      rc=1
    fi
  fi
done

if command -v shellcheck >/dev/null; then
  if shellcheck "${repo_root}/spec/kickstart/run_install.sh" "${repo_root}/spec/kickstart/lint.sh"; then
    echo "ok:   shellcheck spec/kickstart"
  else
    rc=1
  fi
fi

exit $rc
