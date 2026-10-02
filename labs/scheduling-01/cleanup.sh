#!/bin/bash
# scheduling-01 cleanup: remove the lab's cron entry and log file. Other
# root crontab entries stay. cronie goes again if the lab installed it
# (pkg_restore); the exit status is 1 when that fails.
source /opt/linux-labs/lib/packages.sh

current=$(crontab -u root -l 2>/dev/null || true)
remaining=$(printf '%s\n' "$current" | grep -v -e 'Daily task executed' -e 'daily-task\.log' || true)
if [ -n "$remaining" ]; then
	printf '%s\n' "$remaining" | crontab -u root - || true
elif [ -n "$current" ]; then
	crontab -u root -r || true
fi

rm -f /var/log/daily-task.log

rc=0
pkg_restore scheduling-01 || rc=1
[ "$rc" -eq 0 ] && rm -f /opt/linux-labs/state/scheduling-01
exit "$rc"
