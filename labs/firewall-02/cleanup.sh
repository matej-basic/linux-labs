#!/bin/bash
# firewall-02 cleanup: remove the lab rich rule and take the lab
# interface out of the trusted zone. firewalld is left running.
LAB=firewall-02
STATE_FILE=/opt/linux-labs/state/$LAB
RULE='rule family="ipv4" source address="192.168.1.0/24" port port="443" protocol="tcp" accept'

iface=$(head -n 1 "$STATE_FILE" 2>/dev/null)

if command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1; then
	firewall-cmd --permanent --zone=public --remove-rich-rule="$RULE" >/dev/null 2>&1
	if [ -n "$iface" ]; then
		firewall-cmd --permanent --zone=trusted --remove-interface="$iface" >/dev/null 2>&1
		nmcli -g NAME connection show 2>/dev/null | while IFS= read -r name; do
			[ "$(nmcli -g connection.interface-name connection show "$name" 2>/dev/null)" = "$iface" ] || continue
			[ "$(nmcli -g connection.zone connection show "$name" 2>/dev/null)" = trusted ] || continue
			nmcli connection modify "$name" connection.zone "" >/dev/null 2>&1
		done
	fi
	firewall-cmd --reload >/dev/null 2>&1
	firewall-cmd --zone=public --remove-rich-rule="$RULE" >/dev/null 2>&1
	if [ -n "$iface" ] && [ "$(firewall-cmd --get-zone-of-interface="$iface" 2>/dev/null)" = trusted ]; then
		firewall-cmd --zone="$(firewall-cmd --get-default-zone)" --change-interface="$iface" >/dev/null 2>&1
	fi
fi

rm -f "$STATE_FILE"
exit 0
