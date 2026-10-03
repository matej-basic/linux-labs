#!/bin/bash
# networking-01 cleanup: remove labnet-static and re-enable the automatic
# profiles that setup.sh disabled.
STATE_FILE=/opt/linux-labs/state/networking-01

nmcli connection delete labnet-static &>/dev/null || true

# setup.sh disabled autoconnect with --temporary: modify an in-memory
# profile back, load a profile stored on disk again from its file.
restore_profile() {
	local uuid=$1 file
	nmcli connection modify --temporary uuid "$uuid" connection.autoconnect yes &>/dev/null || true
	file=$(nmcli -g UUID,FILENAME connection show 2>/dev/null | sed -n "s/^$uuid://p" | sed 's/\\:/:/g')
	case "$file" in
	"" | /run/*) ;;
	*) nmcli connection load "$file" &>/dev/null || true ;;
	esac
}

if [ -r "$STATE_FILE" ]; then
	tail -n +3 "$STATE_FILE" | while read -r uuid; do
		[ -n "$uuid" ] || continue
		restore_profile "$uuid"
		nmcli --wait 0 connection up uuid "$uuid" &>/dev/null || true
	done
fi

rm -f "$STATE_FILE"
exit 0
