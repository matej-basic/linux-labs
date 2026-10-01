#!/bin/bash
# firewall-03 cleanup: remove what the lab and its solution add and
# restore what setup.sh removed. Never touches ssh or interfaces.
STATE_FILE=/opt/linux-labs/state/firewall-03

fw() { firewall-cmd "$@" >/dev/null 2>&1 || true; }

fw --permanent --zone=internal --remove-masquerade
fw --permanent --zone=public --remove-forward-port=port=8443:proto=tcp:toport=443
fw --permanent --zone=public --remove-service=custom-app
fw --permanent --zone=public --remove-service=http
fw --permanent --delete-service=custom-app
rm -f /etc/firewalld/services/custom-app.xml

# Restore what was there before the lab (only if the lab was started)
if [ -f "$STATE_FILE" ]; then
	grep -qx 'masquerade=1' "$STATE_FILE" && fw --permanent --zone=internal --add-masquerade
	grep -qx 'http=1' "$STATE_FILE" && fw --permanent --zone=public --add-service=http
fi

fw --reload
rm -f "$STATE_FILE"
exit 0
