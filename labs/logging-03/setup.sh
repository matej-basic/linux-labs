#!/bin/bash
# logging-03 setup: volatile journal only (no /var/log/journal) and no
# labtest-fail unit. An existing persistent journal is moved aside on the
# first start and put back by cleanup.sh. Prints nothing on success.
set -eu

STATE_FILE=/opt/linux-labs/state/logging-03
BACKUP=/var/log/journal.labctl-backup

systemctl stop labtest-fail.service 2>/dev/null || true
systemctl reset-failed labtest-fail.service 2>/dev/null || true
rm -f /etc/systemd/system/labtest-fail.service
systemctl daemon-reload

# Record whether a journal existed, only on the first start, so that a
# second start never overwrites the backup.
if [ ! -f "$STATE_FILE" ]; then
	mkdir -p "$(dirname "$STATE_FILE")"
	if [ -d /var/log/journal ] && [ ! -e "$BACKUP" ]; then
		mv /var/log/journal "$BACKUP"
		echo backup > "$STATE_FILE"
	else
		echo none > "$STATE_FILE"
	fi
	chmod 644 "$STATE_FILE"
fi

# Back to volatile storage: journald keeps the old files open until it
# restarts, so restart it after removing the directory.
rm -rf /var/log/journal
systemctl restart systemd-journald
