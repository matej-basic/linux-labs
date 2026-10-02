#!/bin/bash
# dns-03 cleanup: undo setup and the solution (service, zone data, keys,
# named.conf), restore the package set, then drop the named account and
# /var/named if they did not exist before the lab.
source /opt/linux-labs/lib/packages.sh

systemctl stop named >/dev/null 2>&1
systemctl disable named >/dev/null 2>&1
systemctl reset-failed named >/dev/null 2>&1

rm -f /var/named/labsecure.com.zone* /var/named/Klabsecure.com.* \
	/var/named/dsset-labsecure.com.
rc=0
pkg_restore dns-03 || rc=1
if ! rpm -q bind >/dev/null 2>&1; then
	rm -f /etc/named.conf /etc/named.conf.rpmsave
fi
if [ -f /var/tmp/dns-03.pre ]; then
	if ! grep -q named-user /var/tmp/dns-03.pre && ! rpm -q bind >/dev/null 2>&1; then
		rm -rf /var/named
		userdel named >/dev/null 2>&1 || true
		groupdel named >/dev/null 2>&1 || true
	fi
	rm -f /var/tmp/dns-03.pre
fi
exit "$rc"
