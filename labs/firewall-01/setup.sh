#!/bin/bash
# firewall-01 setup: firewalld running, http and 8080/tcp not open in the
# public zone (runtime and permanent). Prints nothing on success.
set -eu

if ! command -v firewall-cmd >/dev/null 2>&1; then
	echo "firewall-01: firewalld is not installed (dnf install firewalld)" >&2
	exit 1
fi

if ! systemctl is-active --quiet firewalld; then
	systemctl enable --now firewalld >/dev/null 2>&1 || {
		echo "firewall-01: cannot start firewalld" >&2
		exit 1
	}
fi

# Firewalld answers on D-Bus a moment after the unit is active
for _ in 1 2 3 4 5 6 7 8 9 10; do
	firewall-cmd --state >/dev/null 2>&1 && break
	sleep 1
done
firewall-cmd --state >/dev/null 2>&1 || {
	echo "firewall-01: firewalld does not respond" >&2
	exit 1
}

# Start without the lab rules; ssh and everything else stay untouched
firewall-cmd --permanent --zone=public --remove-service=http >/dev/null 2>&1 || true
firewall-cmd --permanent --zone=public --remove-port=8080/tcp >/dev/null 2>&1 || true
firewall-cmd --zone=public --remove-service=http >/dev/null 2>&1 || true
firewall-cmd --zone=public --remove-port=8080/tcp >/dev/null 2>&1 || true
exit 0
