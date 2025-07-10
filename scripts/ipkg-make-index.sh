#!/usr/bin/env bash
set -euo pipefail

pkg_dir="$1"

if [[ -z "$pkg_dir" || ! -d "$pkg_dir" ]]; then
    echo "❌ Usage: ipkg-make-index.sh <package_directory>" >&2
    exit 1
fi

empty=1

for pkg in $(find "$pkg_dir" -name '*.ipk' | sort); do
    if ! file "$pkg" | grep -q 'ar archive'; then
        echo "⚠️ Skipping $pkg (not a valid ar archive)"
        continue
    fi

    empty=
    name="${pkg##*/}"
    name="${name%%_*}"

    [[ "$name" = "kernel" || "$name" = "libc" ]] && continue

    echo "📦 Generating index for $pkg" >&2

    file_size=$(stat -c %s "$pkg" || echo 0)
    sha256sum=$(sha256sum "$pkg" | cut -d' ' -f1 || echo "000")

    tmpdir=$(mktemp -d)
    cp "$pkg" "$tmpdir/"
    cd "$tmpdir" || exit 1

    if ! ar x "$(basename "$pkg")"; then
        echo "❌ Failed to extract $pkg with ar"
        rm -rf "$tmpdir"
        continue
    fi

    control_tar=""
    for f in control.tar.gz control.tar.xz control.tar; do
        [ -f "$f" ] && control_tar="$f" && break
    done

    if [[ -z "$control_tar" ]]; then
        echo "❌ No control.tar.* in $pkg"
        rm -rf "$tmpdir"
        continue
    fi

    if ! tar -xf "$control_tar" ./control 2>/dev/null; then
        echo "❌ Failed to extract control from $pkg"
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
done

[ -n "$empty" ] && echo

exit 0
