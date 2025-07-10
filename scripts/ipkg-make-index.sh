#!/bin/sh

pkg_dir="$1"
[ -d "$pkg_dir" ] || {
	echo "Usage: $0 <pkg_directory>" >&2
	exit 1
}

for pkg in "$pkg_dir"/*.ipk; do
	[ -f "$pkg" ] || continue
	echo "Generating index for package $pkg" >&2

	# Try to extract control file from control.tar.gz or control.tar.xz
	control_data=$(ar p "$pkg" control.tar.gz 2>/dev/null | tar xO ./control 2>/dev/null || \
	               ar p "$pkg" control.tar.xz 2>/dev/null | xzcat | tar xO ./control 2>/dev/null)

	if [ -z "$control_data" ]; then
		echo "Warning: Failed to extract control for $pkg" >&2
		continue
	fi

	echo "$control_data"
	echo "Filename: $(basename "$pkg")"
	echo "SHA256sum: $(sha256sum "$pkg" | cut -d' ' -f1)"
	echo
done
