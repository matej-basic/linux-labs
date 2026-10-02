#!/bin/bash
# dns-01 cleanup: remove BIND and everything it leaves behind.
source /opt/linux-labs/lib/packages.sh
systemctl disable --now named >/dev/null 2>&1 || true
rm -f /opt/linux-labs/state/dns-01
rc=0
pkg_restore dns-01 || rc=1
if [ -f /var/tmp/dns-01.pre ]; then
	if ! grep -q named-user /var/tmp/dns-01.pre; then
		rm -rf /var/named
		userdel named >/dev/null 2>&1 || true
		groupdel named >/dev/null 2>&1 || true
	fi
	rm -f /var/tmp/dns-01.pre
fi
exit "$rc"
