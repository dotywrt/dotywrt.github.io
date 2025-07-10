#!/usr/bin/env bash
set -euo pipefail

pkg_dir="$1"

if [[ -z "$pkg_dir" || ! -d "$pkg_dir" ]]; then
    echo "Usage: ipkg-make-index.sh <package_directory>" >&2
    exit 1
fi

empty=1

for pkg in $(find "$pkg_dir" -name '*.ipk' | sort); do
  {
    empty=
    name="${pkg##*/}"
    name="${name%%_*}"
    [[ "$name" = "kernel" ]] && continue
    [[ "$name" = "libc" ]] && continue
    echo "Generating index for package $pkg" >&2

    file_size=$(stat -c %s "$pkg")
    sha256sum=$(sha256sum "$pkg" | cut -d' ' -f1)

    tmpdir=$(mktemp -d)
    cp "$pkg" "$tmpdir/"
    cd "$tmpdir"

    ar x "$(basename "$pkg")" || { echo "⚠️  ar failed on $pkg"; rm -rf "$tmpdir"; continue; }

    control_tar=""
    for f in control.tar.gz control.tar.xz control.tar; do
      [ -f "$f" ] && control_tar="$f" && break
    done

    if [[ -z "$control_tar" ]]; then
      echo "⚠️  No control.tar.* in $pkg"
      rm -rf "$tmpdir"
      continue
    fi

    if ! tar -xf "$control_tar" ./control 2>/dev/null; then
      echo "⚠️  Failed to extract control in $pkg"
      rm -rf "$tmpdir"
      continue
    fi

    sed_safe_pkg=$(echo "$pkg" | sed -e 's/^\.\///g' -e 's/\//\\\//g')
    sed -e "s/^Description:/Filename: $sed_safe_pkg\\
Size: $file_size\\
SHA256sum: $sha256sum\\
Description:/" control

    echo ""
    rm -rf "$tmpdir"
  } || {
    echo "❌ Error processing $pkg, skipping"
  }
done

[ -n "$empty" ] && echo
exit 0
