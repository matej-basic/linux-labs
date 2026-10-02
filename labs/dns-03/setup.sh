#!/bin/bash
# dns-03 setup: start without BIND and without any labsecure.com zone
# data. Prints nothing on success.
set -eu

# First run only: did the named account exist before BIND was installed?
# cleanup.sh removes the account and /var/named only if it did not.
pre=/var/tmp/dns-03.pre
if [ ! -f "$pre" ]; then
	if getent passwd named >/dev/null 2>&1 && ! rpm -q bind >/dev/null 2>&1; then
		echo named-user > "$pre"
	else
		: > "$pre"
	fi
fi

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
	if grep -q named-user "$pre"; then
		rm -f /var/named/labsecure.com.zone* /var/named/Klabsecure.com.* \
			/var/named/dsset-labsecure.com.
	else
		rm -rf /var/named
	fi
fi
exit 0
