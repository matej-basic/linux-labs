#!/bin/bash
# scheduling-01 cleanup: remove the lab's cron entry and log file. Other
# root crontab entries stay.

current=$(crontab -u root -l 2>/dev/null || true)
remaining=$(printf '%s\n' "$current" | grep -v -e 'Daily task executed' -e 'daily-task\.log' || true)
if [ -n "$remaining" ]; then
	printf '%s\n' "$remaining" | crontab -u root - || true
elif [ -n "$current" ]; then
	crontab -u root -r || true
fi

rm -f /var/log/daily-task.log /opt/linux-labs/state/scheduling-01
exit 0
