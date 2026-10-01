#!/bin/bash
# logging-03 cleanup: remove the test unit and the lab's journal, then
# restore the journal that existed before the lab, if any.

STATE_FILE=/opt/linux-labs/state/logging-03
BACKUP=/var/log/journal.labctl-backup

systemctl stop labtest-fail.service 2>/dev/null || true
systemctl reset-failed labtest-fail.service 2>/dev/null || true
rm -f /etc/systemd/system/labtest-fail.service
systemctl daemon-reload 2>/dev/null || true

rm -rf /var/log/journal
if [ -d "$BACKUP" ]; then
	mv "$BACKUP" /var/log/journal
	restorecon -R /var/log/journal 2>/dev/null || true
fi
systemctl restart systemd-journald 2>/dev/null || true
rm -f "$STATE_FILE"
exit 0
