#!/bin/bash
# scheduling-01 setup: make sure cron is available and remove any entry
# or log file left by an earlier run. Other root crontab entries stay.
# Prints nothing on success.
set -eu
source /opt/linux-labs/lib/packages.sh

pkg_snapshot scheduling-01

if ! command -v crontab >/dev/null 2>&1; then
	# dnf reports a repo key import on stderr; show it only on failure
	if ! out=$(dnf -y -q install cronie </dev/null 2>&1); then
		printf '%s\n' "$out" >&2
		echo "Error: cannot install cronie (internet access needed)." >&2
		exit 1
	fi
fi
systemctl enable --now crond >/dev/null 2>&1

current=$(crontab -u root -l 2>/dev/null || true)
remaining=$(printf '%s\n' "$current" | grep -v -e 'Daily task executed' -e 'daily-task\.log' || true)
if [ -n "$remaining" ]; then
	printf '%s\n' "$remaining" | crontab -u root -
elif [ -n "$current" ]; then
	crontab -u root -r
fi

rm -f /var/log/daily-task.log
