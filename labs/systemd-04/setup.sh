#!/bin/bash
set -eu

STATE_DIR="/opt/linux-labs/state"
STATE_FILE="$STATE_DIR/systemd-04"

mkdir -p "$STATE_DIR"

# Keep the original default if a previous start already recorded one,
# so that a second start never makes reset "restore" graphical.target.
original=""
if [ -f "$STATE_FILE" ]; then
	original=$(grep '^original_default=' "$STATE_FILE" | head -n 1 | cut -d= -f2- || true)
fi
if [ -z "$original" ]; then
	original=$(systemctl get-default 2>/dev/null || true)
fi

boot_id=$(cat /proc/sys/kernel/random/boot_id)

cat > "$STATE_FILE" <<STATEEOF
original_default=$original
boot_id=$boot_id
STATEEOF
chmod 0644 "$STATE_FILE"

systemctl set-default graphical.target >/dev/null 2>&1
