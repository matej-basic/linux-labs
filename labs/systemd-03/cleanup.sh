#!/bin/bash
# systemd-03 cleanup: removes the timer, the units, the script and the log.
systemctl stop lab-timer.timer lab-timer.service lab-worker.service >/dev/null 2>&1 || true
systemctl disable lab-timer.timer lab-worker.service >/dev/null 2>&1 || true
rm -f /etc/systemd/system/lab-worker.service \
	/etc/systemd/system/lab-timer.timer \
	/etc/systemd/system/lab-timer.service \
	/etc/systemd/system/timers.target.wants/lab-timer.timer
rm -f /opt/lab-worker.sh
rm -rf /var/lib/lab-worker
systemctl daemon-reload >/dev/null 2>&1 || true
systemctl reset-failed 'lab-*' >/dev/null 2>&1 || true
exit 0
