#!/bin/bash
# dns-02 cleanup: stop named, remove BIND and everything the lab created.
systemctl stop named >/dev/null 2>&1 || true
systemctl disable named >/dev/null 2>&1 || true

if rpm -q bind >/dev/null 2>&1 || rpm -q bind-utils >/dev/null 2>&1; then
	dnf -y -q remove bind bind-utils >/dev/null 2>&1 || true
fi

rm -f /var/named/labdomain.com.zone /var/named/labdomain.com.zone.jnl
if ! rpm -q bind >/dev/null 2>&1; then
	rm -f /etc/named.conf /etc/named.conf.rpmsave
fi
if [ -f /var/tmp/dns-02.pre ]; then
	if ! grep -q named-user /var/tmp/dns-02.pre; then
		rm -rf /var/named
		userdel named >/dev/null 2>&1 || true
		groupdel named >/dev/null 2>&1 || true
	fi
	rm -f /var/tmp/dns-02.pre
fi
exit 0
