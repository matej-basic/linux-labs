#!/bin/bash
# packages-03 setup: make sure curl is installed and remove any file
# list left over from an earlier run. Prints nothing on success.
set -eu

rm -f /tmp/curl-files.txt

if ! rpm -q curl &>/dev/null; then
	# Minimal images may ship curl-minimal, which conflicts with curl
	if ! dnf -y -q install --allowerasing curl >/dev/null 2>&1; then
		echo "Error: could not install the curl package (check network and repositories)" >&2
		exit 1
	fi
fi
