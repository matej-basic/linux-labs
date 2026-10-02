#!/bin/bash
# dns-01 setup: start without BIND installed or running. Prints nothing.
set -eu
source /opt/linux-labs/lib/packages.sh
pkg_snapshot dns-01

# First run only: did the named account exist before BIND was installed?
# The account and /var/named are not package files, so cleanup.sh removes
# them only if they did not exist.
pre=/var/tmp/dns-01.pre
if [ ! -f "$pre" ]; then
	if getent passwd named >/dev/null 2>&1 && ! rpm -q bind >/dev/null 2>&1; then
		echo named-user > "$pre"
	else
		: > "$pre"
	fi
fi

systemctl disable --now named >/dev/null 2>&1 || true
dnf -y -q remove bind bind-chroot bind-utils >/dev/null 2>&1 || true

if rpm -q bind >/dev/null 2>&1 || rpm -q bind-utils >/dev/null 2>&1; then
	echo "dns-01: could not remove the bind packages" >&2
	exit 1
fi
