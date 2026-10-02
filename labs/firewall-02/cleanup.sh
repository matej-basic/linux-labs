#!/bin/bash
# firewall-02 cleanup: delete the lab connection fwlab, put the permanent
# firewalld configuration back as it was before the first start, turn
# the automatic profiles that setup.sh disabled back on, then put the
# package set back.
source /opt/linux-labs/lib/packages.sh
LAB=firewall-02
CONN=fwlab
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
BACKUP="$STATE_DIR/$LAB.firewalld"
RULE='rule family="ipv4" source address="192.168.1.0/24" port port="443" protocol="tcp" accept'

iface=$(head -n 1 "$STATE_FILE" 2>/dev/null)

# Deleting the connection also takes the interface out of its runtime
# zone
if command -v nmcli >/dev/null 2>&1; then
	nmcli -g UUID,NAME connection show 2>/dev/null |
		awk -F: -v c="$CONN" '$2 == c { print $1 }' |
		while read -r uuid; do
			[ -n "$uuid" ] || continue
			nmcli connection delete uuid "$uuid" >/dev/null 2>&1
		done
fi

if [ -d "$BACKUP/zones" ] && [ -f "$BACKUP/firewalld.conf" ]; then
	# Exact copy of the configuration from the first start
	find /etc/firewalld/zones -mindepth 1 -maxdepth 1 -exec rm -rf {} +
	cp -a "$BACKUP/zones/." /etc/firewalld/zones/
	cp -a "$BACKUP/firewalld.conf" /etc/firewalld/firewalld.conf
	restorecon -R /etc/firewalld >/dev/null 2>&1
	if firewall-cmd --state >/dev/null 2>&1; then
		firewall-cmd --reload >/dev/null 2>&1
	fi
elif command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1; then
	# No copy (setup did not get that far): remove what the lab adds
	firewall-cmd --permanent --zone=public --remove-rich-rule="$RULE" >/dev/null 2>&1
	if [ -n "$iface" ]; then
		zone=$(firewall-cmd --permanent --get-zone-of-interface="$iface" 2>/dev/null)
		[ "$zone" != trusted ] ||
			firewall-cmd --permanent --zone=trusted --remove-interface="$iface" >/dev/null 2>&1
	fi
	firewall-cmd --reload >/dev/null 2>&1
fi

# setup.sh disabled autoconnect with --temporary: modify an in-memory
# profile back, load a profile stored on disk again from its file.
if [ -r "$STATE_FILE" ] && command -v nmcli >/dev/null 2>&1; then
	while IFS= read -r line; do
		case "$line" in
			saved=*)
				line=${line#saved=}
				uuid=${line%% *}
				file=${line#* }
				nmcli connection modify --temporary uuid "$uuid" connection.autoconnect yes >/dev/null 2>&1
				case "$file" in
					"" | /run/*) ;;
					*) nmcli connection load "$file" >/dev/null 2>&1 ;;
				esac
				nmcli --wait 0 connection up uuid "$uuid" </dev/null >/dev/null 2>&1
				;;
		esac
	done < "$STATE_FILE"
fi

rm -f "$STATE_FILE"
rm -rf "$BACKUP"
rc=0
pkg_restore "$LAB" || rc=1
exit "$rc"
