#!/usr/bin/env python3

import sys
import os
import gzip
import io
import tarfile

def extract_control_data(ipk_path):
    try:
        with open(ipk_path, 'rb') as f:
            ar_data = f.read()

        # Find control.tar.gz or control.tar.xz inside .ipk
        control_start = ar_data.find(b'control.tar')
        if control_start < 0:
            return None

        gz_start = ar_data.find(b'\x1F\x8B', control_start)
        if gz_start < 0:
            return None

        gz_io = io.BytesIO(ar_data[gz_start:])
        with gzip.GzipFile(fileobj=gz_io) as gz:
            with tarfile.open(fileobj=io.BytesIO(gz.read())) as tar:
                control = tar.extractfile('control')  # <-- FIXED HERE
                if control is None:
                    return None
                return control.read().decode('utf-8')

    except Exception as e:
        print(f"Error extracting control from {ipk_path}: {e}", file=sys.stderr)
        return None

def main():
    if len(sys.argv) != 2:
        print("Usage: %s <pkg_directory>" % sys.argv[0])
        sys.exit(1)

    pkg_dir = sys.argv[1]
    if not os.path.isdir(pkg_dir):
        print("Error: not a directory: %s" % pkg_dir)
        sys.exit(1)

    ipk_files = [f for f in os.listdir(pkg_dir) if f.endswith('.ipk')]
    ipk_files.sort()

    for ipk_file in ipk_files:
        ipk_path = os.path.join(pkg_dir, ipk_file)
        control_data = extract_control_data(ipk_path)
        if control_data:
            print(control_data)
            print("Filename: %s" % ipk_file)
            print()

if __name__ == '__main__':
    main()
