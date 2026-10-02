#!/bin/bash
# dns-03 setup: start without BIND and without any labsecure.com zone
# data. Prints nothing on success.
set -eu
source /opt/linux-labs/lib/packages.sh
pkg_snapshot dns-03

# Stop and remove a previous run or solution
systemctl stop named >/dev/null 2>&1 || true
systemctl disable named >/dev/null 2>&1 || true
systemctl reset-failed named >/dev/null 2>&1 || true

pkgs=()
for p in bind bind-utils bind-dnssec-utils; do
	if rpm -q "$p" >/dev/null 2>&1; then
		pkgs+=("$p")
	fi
done
if [ "${#pkgs[@]}" -gt 0 ]; then
	dnf -y remove "${pkgs[@]}" >/dev/null 2>&1 || true
fi

# With the package gone, nothing else owns these paths
if ! rpm -q bind >/dev/null 2>&1; then
	rm -f /etc/named.conf /etc/named.conf.rpmsave
	if pkg_was_installed dns-03 bind; then
		rm -f /var/named/labsecure.com.zone* /var/named/Klabsecure.com.* \
			/var/named/dsset-labsecure.com.
	else
		rm -rf /var/named
	fi
fi
exit 0
