#!/bin/bash
# dns-02 setup: remove BIND, its configuration and the lab zone so the
# student starts from a clean system. Prints nothing on success.
set -eu
source /opt/linux-labs/lib/packages.sh
pkg_snapshot dns-02

# First run only: did the named account exist before BIND was installed?
# The account and /var/named are not package files, so cleanup.sh removes
# them only if they did not exist.
pre=/var/tmp/dns-02.pre
if [ ! -f "$pre" ]; then
	if getent passwd named >/dev/null 2>&1 && ! rpm -q bind >/dev/null 2>&1; then
		echo named-user > "$pre"
	else
		: > "$pre"
	fi
fi

systemctl stop named >/dev/null 2>&1 || true
systemctl disable named >/dev/null 2>&1 || true

if rpm -q bind >/dev/null 2>&1 || rpm -q bind-utils >/dev/null 2>&1; then
	dnf -y -q remove bind bind-utils >/dev/null 2>&1 || true
fi
if rpm -q bind >/dev/null 2>&1 || rpm -q bind-utils >/dev/null 2>&1; then
	echo "dns-02: could not remove the bind and bind-utils packages" >&2
	exit 1
fi

rm -f /var/named/labdomain.com.zone /var/named/labdomain.com.zone.jnl \
	/etc/named.conf /etc/named.conf.rpmsave
exit 0
