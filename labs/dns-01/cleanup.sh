#!/bin/bash
# dns-01 cleanup: remove BIND and everything it leaves behind. When BIND
# was not installed at the first start, its data and configuration go
# before pkg_restore, so that pkg_restore can remove the named user and
# group the package created.
source /opt/linux-labs/lib/packages.sh
systemctl disable --now named >/dev/null 2>&1 || true
rm -f /opt/linux-labs/state/dns-01
if ! pkg_was_installed dns-01 bind; then
	rm -rf /var/named
	rm -f /etc/named.conf /etc/named.conf.rpmsave /etc/rndc.key
fi
rc=0
pkg_restore dns-01 || rc=1
# Record file of earlier versions of this lab
rm -f /var/tmp/dns-01.pre
exit "$rc"
