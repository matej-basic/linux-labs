#!/bin/bash
# dns-03 cleanup: undo setup and the solution (service, zone data, keys,
# named.conf), then restore the package set. When BIND was not installed
# at the first start, /var/named and the configuration go before
# pkg_restore, so that pkg_restore can remove the named user and group
# the package created.
source /opt/linux-labs/lib/packages.sh

systemctl stop named >/dev/null 2>&1
systemctl disable named >/dev/null 2>&1
systemctl reset-failed named >/dev/null 2>&1

rm -f /var/named/labsecure.com.zone* /var/named/Klabsecure.com.* \
	/var/named/dsset-labsecure.com.
if ! pkg_was_installed dns-03 bind; then
	rm -rf /var/named
	rm -f /etc/named.conf /etc/named.conf.rpmsave /etc/rndc.key
fi
rc=0
pkg_restore dns-03 || rc=1
# Record file of earlier versions of this lab
rm -f /var/tmp/dns-03.pre
exit "$rc"
