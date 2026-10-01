#!/bin/bash
# selinux-01 cleanup: return SELinux to enforcing, as on the student VMs.
CONF=/etc/selinux/config

if command -v getenforce >/dev/null 2>&1 && [ "$(getenforce 2>/dev/null)" != "Disabled" ]; then
	setenforce 1 2>/dev/null || true
	if [ -f "$CONF" ] && grep -Eq '^SELINUX=permissive' "$CONF"; then
		sed -i -E 's/^SELINUX=permissive/SELINUX=enforcing/' "$CONF"
	fi
fi
exit 0
