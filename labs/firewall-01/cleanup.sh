#!/bin/bash
# firewall-01 cleanup: remove the http service and 8080/tcp from the public
# zone, runtime and permanent. ssh and other rules are left alone.

if command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1; then
	firewall-cmd --permanent --zone=public --remove-service=http >/dev/null 2>&1 || true
	firewall-cmd --permanent --zone=public --remove-port=8080/tcp >/dev/null 2>&1 || true
	firewall-cmd --zone=public --remove-service=http >/dev/null 2>&1 || true
	firewall-cmd --zone=public --remove-port=8080/tcp >/dev/null 2>&1 || true
fi
exit 0
