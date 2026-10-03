#!/bin/bash
# files-07 cleanup: removes the timer and service, the backup script,
# lab-churn, /srv/data, the snapshots (/backup itself when the lab
# created it), the lab users and group the lab created and the state
# directory. Then the package set of the first start comes back (rsync
# goes again).
source /opt/linux-labs/lib/packages.sh

LAB=files-07
STATE_DIR=/opt/linux-labs/state/$LAB
FLAGS=$STATE_DIR/flags
MARK="files-07 lab user"
rc=0

had() {
	grep -qx "$1" "$FLAGS" 2>/dev/null
}

for unit in snapshot-backup.timer snapshot-backup.service; do
	systemctl disable --now "$unit" >/dev/null 2>&1 || true
done
rm -f /etc/systemd/system/snapshot-backup.service \
	/etc/systemd/system/snapshot-backup.timer \
	/etc/systemd/system/timers.target.wants/snapshot-backup.timer \
	/var/lib/systemd/timers/stamp-snapshot-backup.timer \
	/usr/local/sbin/snapshot-backup /usr/local/sbin/lab-churn
systemctl daemon-reload >/dev/null 2>&1 || true
systemctl reset-failed snapshot-backup.service snapshot-backup.timer \
	>/dev/null 2>&1 || true

rm -rf /srv/data
rm -rf /backup/snapshots
if [ -f "$FLAGS" ] && ! had backup-existed; then
	rm -rf /backup
else
	rmdir /backup 2>/dev/null
fi

# Lab users: those the lab created (by the flags, or by the comment when
# the flags are gone)
for u in snapdev snapops; do
	getent passwd "$u" >/dev/null || continue
	if [ -f "$FLAGS" ]; then
		had "user-existed-$u" && continue
	elif [ "$(getent passwd "$u" | cut -d: -f5)" != "$MARK" ]; then
		continue
	fi
	userdel "$u" >/dev/null 2>&1 || rc=1
	rm -f "/var/spool/mail/$u"
done
if getent group snapteam >/dev/null && ! had group-existed; then
	gid=$(getent group snapteam | cut -d: -f3)
	if [ -f "$FLAGS" ] || ! awk -F: -v g="$gid" '$4 == g { f = 1 } END { exit !f }' /etc/passwd; then
		groupdel snapteam >/dev/null 2>&1 || rc=1
	fi
fi

rm -rf "$STATE_DIR"

pkg_restore "$LAB" || rc=1
exit "$rc"
