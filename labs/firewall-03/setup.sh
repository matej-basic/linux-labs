#!/bin/bash
# firewall-03 setup: make sure firewalld runs and remove the settings the
# lab asks for. What was there before is recorded in the state file so
# that cleanup.sh can restore it. Prints nothing on success.
set -eu

STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/firewall-03"

if ! command -v firewall-cmd >/dev/null 2>&1; then
	echo "firewall-03: firewalld is not installed (dnf install firewalld)" >&2
	exit 1
fi

systemctl enable --now firewalld >/dev/null 2>&1 || {
	echo "firewall-03: cannot start firewalld" >&2
	exit 1
}
for _ in $(seq 1 30); do
	firewall-cmd --state >/dev/null 2>&1 && break
	sleep 1
done
if ! firewall-cmd --state >/dev/null 2>&1; then
	echo "firewall-03: firewalld is not responding" >&2
	exit 1
fi

# Remember the original permanent state once; a second run keeps it.
mkdir -p "$STATE_DIR"
if [ ! -f "$STATE_FILE" ]; then
	{
		if firewall-cmd --permanent --zone=internal --query-masquerade >/dev/null 2>&1; then
			echo "masquerade=1"
		else
			echo "masquerade=0"
		fi
		if firewall-cmd --permanent --zone=public --query-service=http >/dev/null 2>&1; then
			echo "http=1"
		else
			echo "http=0"
		fi
	} > "$STATE_FILE"
	chmod 644 "$STATE_FILE"
fi

# Reset to the starting state (permanent first, then reload)
fw() { firewall-cmd "$@" >/dev/null 2>&1 || true; }
fw --permanent --zone=internal --remove-masquerade
fw --permanent --zone=public --remove-forward-port=port=8443:proto=tcp:toport=443
fw --permanent --zone=public --remove-service=custom-app
fw --permanent --zone=public --remove-service=http
fw --permanent --delete-service=custom-app
rm -f /etc/firewalld/services/custom-app.xml
firewall-cmd --reload >/dev/null 2>&1 || {
	echo "firewall-03: firewalld reload failed" >&2
	exit 1
}
