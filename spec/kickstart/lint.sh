#!/bin/bash
#
# Lint the EL kickstarts.
#
# Usage: lint.sh [KSVALIDATOR]
#
# - Validates each .cfg file with pykickstart's ksvalidator, for its EL
#   version, after replacing the #PLACEHOLDERS# (a '#' starts a comment).
# - Checks that each .cfg file uses only the known placeholders, has one
#   `url` for its EL version, and runs repodetect.sh for its EL version.
# - Checks that the EL8 and EL9 .cfg files differ from EL10's only in the
#   version.
# - Checks that EL8's and EL9's diskdetect.sh and repodetect.sh are symlinks
#   to EL10's, since they support all of them.
# - Runs ShellCheck on the helper scripts, if it's installed.

set -euo pipefail

ksvalidator="${1:-ksvalidator}"
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

versions=(8 9 10)
newest=10
placeholders='BOOTPASS|KSSERVER|LINUXDIST|ROOTPASS|YUMSERVER'
rc=0

ks_dir() { echo "${repo_root}/build/distributions/RedHat/$1/x86_64/DVD/ks"; }

# normalize VERSION FILE: FILE with its EL version replaced by 'N'
normalize() {
  sed -E \
    -e "s/EL$1([^0-9]|$)/ELN\1/g" \
    -e "s#/$1/x86_64#/N/x86_64#g" \
    -e "s/'$1'/'N'/g" \
    "$2"
}

for version in "${versions[@]}"; do
  for cfg in "$(ks_dir "$version")"/*.cfg; do
    name="EL${version}/$(basename "$cfg")"
    # shellcheck disable=SC2016 # a literal password hash
    sed \
      -e 's/#ROOTPASS#/$6$salt$hash/' \
      -e 's/#BOOTPASS#/grub.pbkdf2.sha512.10000.00.00/' \
      -e 's/#[A-Z]\{1,\}#/placeholder/g' \
      "$cfg" > "${tmp}/ks.cfg"

    unknown="$(grep -oE '#[A-Z]+#' "$cfg" | grep -vxE "#(${placeholders})#" | sort -u | tr '\n' ' ' || :)"
    if [ -n "$unknown" ]; then
      echo "FAIL: ${name}: unknown placeholder(s): ${unknown}"
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
    # dracut reads the `url` to find the installer's second stage.
    urls="$(grep -cE '^url ' "$cfg" || :)"
    if [ "$urls" != 1 ]; then
      echo "FAIL: ${name}: has ${urls} 'url' lines; expected 1"
      rc=1
    elif ! grep -E '^url ' "$cfg" | grep -qE "/${version}/x86_64( |$)"; then
      echo "FAIL: ${name}: the 'url' is not for EL${version}"
      rc=1
    fi

    if [ "$version" != "$newest" ]; then
      newest_cfg="$(ks_dir "$newest")/$(basename "$cfg")"
      if ! diff -u --label "EL${newest}/$(basename "$cfg")" --label "$name" \
          <(normalize "$newest" "$newest_cfg") <(normalize "$version" "$cfg"); then
        echo "FAIL: ${name} differs from EL${newest}'s in more than the version"
        rc=1
      fi
    fi
  done
done

for script in diskdetect.sh repodetect.sh; do
  reference="$(ks_dir "$newest")/${script}"
  for version in "${versions[@]}"; do
    [ "$version" = "$newest" ] && continue
    link="$(ks_dir "$version")/${script}"
    if [ ! -L "$link" ] || [ "$(readlink -f "$link")" != "$(readlink -f "$reference")" ]; then
      echo "FAIL: EL${version}/${script} is not a symlink to EL${newest}/${script}"
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
  if shellcheck "${repo_root}/spec/kickstart/run_install.sh" "${repo_root}/spec/kickstart/lint.sh" \
      "${repo_root}/spec/kickstart/files/bootstrap_simp_client"; then
    echo "ok:   shellcheck spec/kickstart"
  else
    rc=1
  fi
fi

exit $rc
