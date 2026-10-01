#!/bin/bash
# networking-01 cleanup: remove labnet-static and re-enable the automatic
# profiles that setup.sh disabled.
STATE_FILE=/opt/linux-labs/state/networking-01

nmcli connection delete labnet-static &>/dev/null || true

if [ -r "$STATE_FILE" ]; then
	tail -n +3 "$STATE_FILE" | while read -r uuid; do
		[ -n "$uuid" ] || continue
		nmcli connection modify uuid "$uuid" connection.autoconnect yes &>/dev/null || true
		nmcli --wait 0 connection up uuid "$uuid" &>/dev/null || true
	done
fi

rm -f "$STATE_FILE"
exit 0
