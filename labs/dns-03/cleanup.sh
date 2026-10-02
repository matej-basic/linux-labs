#!/bin/bash
# dns-03 cleanup: undo setup and the solution (service, packages, zone
# data, keys, named.conf). Setup removed the packages, so they go again.

systemctl stop named >/dev/null 2>&1
systemctl disable named >/dev/null 2>&1
systemctl reset-failed named >/dev/null 2>&1

pkgs=()
for p in bind bind-utils bind-dnssec-utils; do
	if rpm -q "$p" >/dev/null 2>&1; then
		pkgs+=("$p")
	fi
done
if [ "${#pkgs[@]}" -gt 0 ]; then
	dnf -y remove "${pkgs[@]}" >/dev/null 2>&1
fi

if ! rpm -q bind >/dev/null 2>&1; then
	rm -f /etc/named.conf /etc/named.conf.rpmsave
	rm -f /var/named/labsecure.com.zone* /var/named/Klabsecure.com.* \
		/var/named/dsset-labsecure.com.
fi
if [ -f /var/tmp/dns-03.pre ]; then
	if ! grep -q named-user /var/tmp/dns-03.pre && ! rpm -q bind >/dev/null 2>&1; then
		rm -rf /var/named
		userdel named >/dev/null 2>&1 || true
		groupdel named >/dev/null 2>&1 || true
	fi
	rm -f /var/tmp/dns-03.pre
fi
exit 0
