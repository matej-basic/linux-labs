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
	rm -rf /var/named
fi
exit 0
