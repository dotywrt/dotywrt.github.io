#!/usr/bin/env bash
set -e

pkg_dir="$1"

if [ -z "$pkg_dir" ] || [ ! -d "$pkg_dir" ]; then
    echo "Usage: ipkg-make-index <package_directory>" >&2
    exit 1
fi

empty=1

for pkg in $(find "$pkg_dir" -name '*.ipk' | sort); do
    empty=
    name="${pkg##*/}"
    name="${name%%_*}"
    [[ "$name" = "kernel" ]] && continue
    [[ "$name" = "libc" ]] && continue
    echo "Generating index for package $pkg" >&2

    file_size=$(stat -L -c%s "$pkg")
    sha256sum=$(sha256sum "$pkg" | cut -d' ' -f1)

    tmpdir=$(mktemp -d)
    ar x "$pkg" --output="$tmpdir" >/dev/null 2>&1

    control_tar=""
    if [[ -f "$tmpdir/control.tar.gz" ]]; then
        control_tar="$tmpdir/control.tar.gz"
    elif [[ -f "$tmpdir/control.tar.xz" ]]; then
        control_tar="$tmpdir/control.tar.xz"
    elif [[ -f "$tmpdir/control.tar" ]]; then
        control_tar="$tmpdir/control.tar"
    else
        echo "Warning: No control.tar.* found in $pkg" >&2
        rm -rf "$tmpdir"
        continue
    fi

    if ! tar -C "$tmpdir" -xf "$control_tar" ./control 2>/dev/null; then
        echo "Warning: Failed to extract control from $pkg" >&2
        rm -rf "$tmpdir"
        continue
    fi

    sed_safe_pkg=$(echo "$pkg" | sed -e 's/^\.\///g' -e 's/\//\\\//g')
    sed -e "s/^Description:/Filename: $sed_safe_pkg\\
Size: $file_size\\
SHA256sum: $sha256sum\\
Description:/" "$tmpdir/control"
    echo ""

    rm -rf "$tmpdir"
done

[ -n "$empty" ] && echo
exit 0
