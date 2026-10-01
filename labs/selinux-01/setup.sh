#!/bin/bash
# selinux-01 setup: put SELinux into permissive mode, at runtime and in
# the configuration file. Prints nothing on success.
set -eu

CONF=/etc/selinux/config

if ! command -v getenforce >/dev/null 2>&1 || ! command -v setenforce >/dev/null 2>&1; then
	echo "SELinux tools are not installed (package policycoreutils)." >&2
	exit 1
fi

if [ "$(getenforce)" = "Disabled" ] || [ ! -f "$CONF" ]; then
	echo "SELinux is disabled on this system. This lab needs it enabled" >&2
	echo "(permissive or enforcing). Enable it and reboot first." >&2
	exit 1
fi

if grep -Eq '^SELINUX=disabled' "$CONF"; then
	echo "SELINUX=disabled in $CONF. Set it to enforcing and reboot first." >&2
	exit 1
fi

setenforce 0
sed -i -E 's/^SELINUX=.*/SELINUX=permissive/' "$CONF"
