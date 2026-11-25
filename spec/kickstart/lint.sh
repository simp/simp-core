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
# - Validates each ISO kickstart (ks/dvd/*.cfg) with ksvalidator, with its
#   ISO-only %include files inlined (each must exist), checks that it runs
#   repodetect.sh for its EL version, and checks the shell syntax of its
#   shell sections (%pre, %pre-install, %post, %onerror, %traceback) with
#   `bash -n`.
# - Runs ShellCheck on the helper scripts, if it's installed.

set -euo pipefail
shopt -s nullglob

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

# The ISO kickstarts %include files from /mnt/install/repo, which only exists
# on the ISO, so inline them, and record in ks.map where each line of ks.cfg
# came from. The /tmp includes are written by %pre at install time;
# ksvalidator skips them without -i.
# where N: the file and line that line N of ks.cfg came from
where() { echo "${map[$1 - 1]:-?}"; }
iso_include='^%include[[:space:]]+/mnt/install/repo/ks/dvd/([^[:space:]]+)[[:space:]]*$'
for version in "${versions[@]}"; do
  dvd="$(ks_dir "$version")/dvd"
  [ -d "$dvd" ] || continue
  for cfg in "$dvd"/*.cfg; do
    src="dvd/$(basename "$cfg")"
    name="EL${version}/${src}"
    : > "${tmp}/ks.cfg"
    : > "${tmp}/ks.map"
    lineno=0
    while IFS= read -r line || [ -n "$line" ]; do
      lineno=$((lineno + 1))
      if [[ $line =~ $iso_include ]]; then
        inc="${BASH_REMATCH[1]}"
        if [ -f "${dvd}/${inc}" ]; then
          awk -v f="dvd/${inc}" -v m="${tmp}/ks.map" \
            '{ print; print f ":" NR >> m }' "${dvd}/${inc}" >> "${tmp}/ks.cfg"
        else
          echo "FAIL: ${name}:${lineno}: %include target dvd/${inc} does not exist"
          rc=1
        fi
        continue
      fi
      printf '%s\n' "$line" >> "${tmp}/ks.cfg"
      echo "${src}:${lineno}" >> "${tmp}/ks.map"
    done < "$cfg"
    mapfile -t map < "${tmp}/ks.map"

    # ksvalidator without -i skips an %include it can't read, so fail on any
    # ISO include left over (an unexpected form, or one in an included file).
    leftover="$(awk 'NR == FNR { m[NR] = $0; next }
                     /^[[:space:]]*%include[[:space:]]+\/mnt\/install\/repo/ { print m[FNR] ": " $0 }' \
                  "${tmp}/ks.map" "${tmp}/ks.cfg")"
    if [ -n "$leftover" ]; then
      echo "FAIL: ${name}: %include from the ISO that wasn't inlined"
      printf '      %s\n' "$leftover"
      rc=1
    fi

    if out="$("$ksvalidator" -e -v "RHEL${version}" "${tmp}/ks.cfg" 2>&1)"; then
      echo "ok:   ${name}"
    else
      echo "FAIL: ${name}"
      # ksvalidator's line numbers are in ks.cfg; add where each came from.
      while IFS= read -r msg; do
        if [[ $msg =~ on\ line\ ([0-9]+)\ of\ the\ kickstart\ file ]]; then
          msg="${msg} ($(where "${BASH_REMATCH[1]}"))"
        fi
        printf '      %s\n' "$msg"
      done <<< "$out"
      rc=1
    fi

    if ! grep -qE "repodetect\.sh '${version}'" "$cfg"; then
      echo "FAIL: ${name}: does not run repodetect.sh for EL${version}"
      rc=1
    fi

    # ksvalidator doesn't parse shell, so check each shell section's body.
    # section<N>.hdr holds the header's line number in ks.cfg and the header.
    rm -f "${tmp}"/section*
    awk -v d="$tmp" '
      /^%(pre|pre-install|post|onerror|traceback)([[:space:]]|$)/ {
        f = !match($0, /--interpreter[= ]+[^ ]+/) ||
            substr($0, RSTART, RLENGTH) ~ /[=\/ ](ba)?sh$/
        if (f) { n++; print NR "\t" $0 > (d "/section" n ".hdr") }
        next
      }
      /^%end/ { f = 0 }
      f { print > (d "/section" n ".sh") }' "${tmp}/ks.cfg"
    for hdr in "${tmp}"/section*.hdr; do
      section="${hdr%.hdr}.sh"
      [ -e "$section" ] || continue
      IFS=$'\t' read -r start header < "$hdr"
      if ! out="$(bash -n "$section" 2>&1)"; then
        echo "FAIL: ${name}: shell syntax error in '${header}' ($(where "$start"))"
        # bash numbers the lines from the start of the section; map them back.
        while IFS= read -r msg; do
          if [[ $msg =~ ^"$section":\ line\ ([0-9]+):\ (.*)$ ]]; then
            msg="$(where $((start + BASH_REMATCH[1]))): ${BASH_REMATCH[2]}"
          fi
          if [[ $msg =~ ^(.*)\ on\ line\ ([0-9]+)$ ]]; then
            msg="${BASH_REMATCH[1]} at $(where $((start + BASH_REMATCH[2])))"
          fi
          printf '      %s\n' "$msg"
        done <<< "$out"
        rc=1
      fi
    done
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
