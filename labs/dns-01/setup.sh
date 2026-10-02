#!/bin/bash
# dns-01 setup: start without BIND installed or running. Prints nothing.
set -eu
source /opt/linux-labs/lib/packages.sh
pkg_snapshot dns-01

systemctl disable --now named >/dev/null 2>&1 || true
dnf -y -q remove bind bind-chroot bind-utils >/dev/null 2>&1 || true

if rpm -q bind >/dev/null 2>&1 || rpm -q bind-utils >/dev/null 2>&1; then
	echo "dns-01: could not remove the bind packages" >&2
	exit 1
fi
