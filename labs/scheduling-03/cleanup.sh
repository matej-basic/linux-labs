#!/bin/bash
# scheduling-03 cleanup: remove the anacron job, the timer, the scripts and
# logs, and restore root's crontab from the backup made by setup.sh.
STATE_DIR=/opt/linux-labs/state/scheduling-03

# Anacron job (in place, to keep mode and SELinux context)
if grep -q 'anacron_lab' /etc/anacrontab 2>/dev/null; then
	tmp=$(mktemp)
	grep -v 'anacron_lab' /etc/anacrontab > "$tmp"
	cat "$tmp" > /etc/anacrontab
	rm -f "$tmp"
fi
rm -f /var/spool/anacron/anacron_lab /usr/local/bin/anacron-task.sh \
	/var/log/anacron-task.log

# Systemd timer
systemctl disable --now persistent-timer.timer >/dev/null 2>&1 || true
systemctl stop persistent-timer.service >/dev/null 2>&1 || true
rm -f /etc/systemd/system/persistent-timer.service \
	/etc/systemd/system/persistent-timer.timer \
	/etc/systemd/system/timers.target.wants/persistent-timer.timer \
	/usr/local/bin/persistent-task.sh /var/log/persistent-task.log
systemctl daemon-reload >/dev/null 2>&1 || true
systemctl reset-failed persistent-timer.service persistent-timer.timer \
	>/dev/null 2>&1 || true

# Root's crontab: restore the original
if [ -f "$STATE_DIR/crontab.orig" ]; then
	crontab -u root "$STATE_DIR/crontab.orig" >/dev/null 2>&1 || true
elif [ -f "$STATE_DIR/no-crontab" ]; then
	crontab -r -u root >/dev/null 2>&1 || true
fi
rm -f /usr/local/bin/env-task.sh /var/log/env-task.log

rm -rf "$STATE_DIR"
exit 0
