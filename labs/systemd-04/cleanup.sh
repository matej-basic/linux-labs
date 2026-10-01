#!/bin/bash
# Restore the recorded default target. No isolate and no reboot: the
# running system is left as it is.
STATE_FILE="/opt/linux-labs/state/systemd-04"

original=""
if [ -f "$STATE_FILE" ]; then
	original=$(grep '^original_default=' "$STATE_FILE" | head -n 1 | cut -d= -f2-)
fi

if [ -n "$original" ]; then
	systemctl set-default "$original" >/dev/null 2>&1 || true
fi

rm -f "$STATE_FILE"
exit 0
