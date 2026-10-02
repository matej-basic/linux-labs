#!/bin/bash
# scheduling-03 setup: snapshot the packages, make sure cronie and
# cronie-anacron are installed (reset removes what the lab added), remove
# earlier lab files and back up root's crontab so cleanup can restore it.
# Prints nothing on success.
set -eu
source /opt/linux-labs/lib/packages.sh

pkg_snapshot scheduling-03

STATE_DIR=/opt/linux-labs/state/scheduling-03

for pkg in cronie cronie-anacron; do
	if ! rpm -q "$pkg" >/dev/null 2>&1; then
		dnf -y -q install "$pkg" >/dev/null || {
			echo "Error: cannot install $pkg (internet access needed)." >&2
			exit 1
		}
	fi
done
[ -f /etc/anacrontab ] || {
	echo "Error: /etc/anacrontab is missing." >&2
	exit 1
}

# Remove leftovers of an earlier run or of the solution
systemctl disable --now persistent-timer.timer >/dev/null 2>&1 || true
systemctl stop persistent-timer.service >/dev/null 2>&1 || true
rm -f /etc/systemd/system/persistent-timer.service \
	/etc/systemd/system/persistent-timer.timer \
	/etc/systemd/system/timers.target.wants/persistent-timer.timer \
	/usr/local/bin/persistent-task.sh /usr/local/bin/anacron-task.sh \
	/usr/local/bin/env-task.sh /var/log/persistent-task.log \
	/var/log/anacron-task.log /var/log/env-task.log \
	/var/spool/anacron/anacron_lab
systemctl daemon-reload >/dev/null 2>&1 || true
systemctl reset-failed persistent-timer.service persistent-timer.timer \
	>/dev/null 2>&1 || true

# Anacrontab without any lab line (written in place to keep mode and context)
if grep -q 'anacron_lab' /etc/anacrontab; then
	tmp=$(mktemp)
	grep -v 'anacron_lab' /etc/anacrontab > "$tmp" || true
	cat "$tmp" > /etc/anacrontab
	rm -f "$tmp"
fi

# Back up root's crontab once (an earlier started run keeps its backup)
if [ ! -f "$STATE_DIR/started" ]; then
	rm -rf "$STATE_DIR"
	mkdir -p "$STATE_DIR"
	if crontab -l -u root > "$STATE_DIR/crontab.orig" 2>/dev/null; then
		:
	else
		rm -f "$STATE_DIR/crontab.orig"
		: > "$STATE_DIR/no-crontab"
	fi
	: > "$STATE_DIR/started"
fi
# The lab's own variables and job must not survive a restart of the lab
if [ -f "$STATE_DIR/crontab.orig" ]; then
	crontab -u root "$STATE_DIR/crontab.orig"
else
	crontab -r -u root >/dev/null 2>&1 || true
fi
chmod 755 "$STATE_DIR"
chmod 644 "$STATE_DIR"/* 2>/dev/null || true
