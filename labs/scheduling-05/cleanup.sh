#!/bin/bash
# scheduling-05 cleanup: remove the two files in /etc/cron.d, the
# crontab and the account of the user reports, the helper, the logs and
# the state, and put crond back into the state setup.sh recorded at the
# first start. Safe when the lab was never started.
LAB=scheduling-05
STATE_FILE=/opt/linux-labs/state/$LAB
USR=reports
rc=0

state_value() {
	[ -r "$STATE_FILE" ] || return 0
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}

rm -f /etc/cron.d/lab-backup /etc/cron.d/lab-cleanup
if id "$USR" >/dev/null 2>&1; then
	crontab -u "$USR" -r >/dev/null 2>&1 || true
	pkill -KILL -u "$USR" 2>/dev/null || true
	sleep 1
	userdel -r "$USR" >/dev/null 2>&1 || {
		echo "Error: cannot remove the user $USR." >&2
		rc=1
	}
fi
rm -f /var/spool/cron/"$USR"
rm -f /usr/local/sbin/lab-report
rm -rf /var/log/cronlab

# crond as it was before the lab
if [ "$(state_value crond_was_enabled)" = no ]; then
	systemctl disable crond >/dev/null 2>&1 || true
fi
if [ "$(state_value crond_was_active)" = no ]; then
	systemctl stop crond >/dev/null 2>&1 || true
fi

[ "$rc" -eq 0 ] && rm -f "$STATE_FILE" "$STATE_FILE.tmp"
exit "$rc"
