#!/bin/bash
# dns-02 cleanup: stop named, remove BIND and everything the lab created.
# When BIND was not installed at the first start, its data and
# configuration go before pkg_restore, so that pkg_restore can remove
# the named user and group the package created.
source /opt/linux-labs/lib/packages.sh
systemctl stop named >/dev/null 2>&1 || true
systemctl disable named >/dev/null 2>&1 || true

rm -f /var/named/labdomain.com.zone /var/named/labdomain.com.zone.jnl
if ! pkg_was_installed dns-02 bind; then
	rm -rf /var/named
	rm -f /etc/named.conf /etc/named.conf.rpmsave /etc/rndc.key
fi
rc=0
pkg_restore dns-02 || rc=1
# Record file of earlier versions of this lab
rm -f /var/tmp/dns-02.pre
exit "$rc"
