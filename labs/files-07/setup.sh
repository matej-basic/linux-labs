#!/bin/bash
# files-07 setup: builds the data tree /srv/data (owners snapdev, snapops,
# the task user and root, group snapteam, mixed modes, fixed times, three
# .cache files) and installs /usr/local/sbin/lab-churn, which changes,
# adds and deletes one file of the tree and records each run in the state
# directory. Removes what an earlier run or the solution left: the
# script, the units, the snapshots.
#
# The first run records the package set (lib/packages.sh) and in
# /opt/linux-labs/state/files-07/flags what existed before (/backup, the
# lab users and group), so that cleanup.sh removes exactly what the lab
# added. Prints nothing on success.
set -eu
source /opt/linux-labs/lib/packages.sh

LAB=files-07
STATE_DIR=/opt/linux-labs/state/$LAB
FLAGS=$STATE_DIR/flags
DATA=/srv/data
MARK="files-07 lab user"

pkg_snapshot "$LAB"

# The task user, see files-04
owner="${LAB_USER:-student}"
if ! id "$owner" &>/dev/null; then
	owner=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 { print $1; exit }')
	owner="${owner:-root}"
fi
ogroup=$(id -gn "$owner")

# First run only: what existed before the lab
if [ ! -f "$FLAGS" ]; then
	mkdir -p "$STATE_DIR"
	{
		[ -e /backup ] && echo backup-existed
		getent group snapteam >/dev/null && echo group-existed
		for u in snapdev snapops; do
			getent passwd "$u" >/dev/null && echo "user-existed-$u"
		done
		true
	} > "$FLAGS.tmp"
	mv "$FLAGS.tmp" "$FLAGS"
fi
chmod 0755 "$STATE_DIR"
chmod 0644 "$FLAGS"
rm -f "$STATE_DIR/churn"

# Leftovers of an earlier run or of the solution
for unit in snapshot-backup.timer snapshot-backup.service; do
	systemctl disable --now "$unit" >/dev/null 2>&1 || true
done
rm -f /etc/systemd/system/snapshot-backup.service \
	/etc/systemd/system/snapshot-backup.timer \
	/etc/systemd/system/timers.target.wants/snapshot-backup.timer \
	/var/lib/systemd/timers/stamp-snapshot-backup.timer \
	/usr/local/sbin/snapshot-backup
systemctl daemon-reload >/dev/null 2>&1 || true
systemctl reset-failed snapshot-backup.service snapshot-backup.timer \
	>/dev/null 2>&1 || true
if grep -qx backup-existed "$FLAGS"; then
	rm -rf /backup/snapshots
else
	rm -rf /backup
fi

# Lab users and group
getent group snapteam >/dev/null || groupadd snapteam
for u in snapdev snapops; do
	if ! getent passwd "$u" >/dev/null; then
		useradd -M -g snapteam -s /sbin/nologin -c "$MARK" "$u"
	fi
done

# d <mode> <owner:group> <path>: a directory
d() {
	mkdir "$3" && chown "$2" "$3" && chmod "$1" "$3"
}
# f <mode> <owner:group> <mtime> <path> <content>: a regular file
f() {
	printf '%b' "$5" > "$4" && chown "$2" "$4" && chmod "$1" "$4" &&
		touch -d "$3" "$4"
}

rm -rf "$DATA"
umask 022
d 0755 root:root $DATA
d 2775 snapdev:snapteam $DATA/projects
d 0750 snapops:snapteam $DATA/reports
d 0700 root:root $DATA/config
f 0644 root:root "2025-01-06 08:15:00" $DATA/README.txt \
	"Working data of the projects and reports teams.\nBacked up to /backup/snapshots.\n"
f 0664 snapdev:snapteam "2025-02-03 10:20:31" $DATA/projects/plan.txt \
	"Milestone 1: prototype\nMilestone 2: field test\nMilestone 3: release\n"
f 0664 snapdev:snapteam "2025-02-12 15:02:44" $DATA/projects/notes.txt \
	"Prototype review moved to Thursday.\n"
f 0640 "$owner:$ogroup" "2025-02-14 09:41:10" $DATA/projects/todo.txt \
	"- order test hardware\n- update the field test plan\n"
f 0664 snapdev:snapteam "2025-02-14 17:30:05" $DATA/projects/build.cache \
	"build cache, safe to delete\n"
f 0640 snapops:snapteam "2025-03-31 18:00:00" $DATA/reports/q1.csv \
	"month,tickets\njan,42\nfeb,37\nmar,51\n"
f 0640 snapops:snapteam "2025-06-30 18:00:00" $DATA/reports/q2.csv \
	"month,tickets\napr,45\nmay,39\njun,48\n"
f 0640 snapops:snapteam "2025-07-01 06:00:00" $DATA/reports/index.cache \
	"index cache, safe to delete\n"
f 0600 root:root "2024-12-02 11:11:11" $DATA/config/app.conf \
	"listen=8080\nlog_level=info\n"
f 0600 root:root "2025-07-01 06:00:00" $DATA/config/session.cache \
	"session cache, safe to delete\n"
for dir in $DATA/projects $DATA/reports $DATA/config $DATA; do
	touch -d "2025-07-01 06:00:00" "$dir"
done
restorecon -R $DATA >/dev/null 2>&1 || true

# lab-churn: one day of work in /srv/data
cat > /usr/local/sbin/lab-churn <<'PROGRAM'
#!/bin/bash
# lab-churn: simulates one day of work in /srv/data for the files-07
# lab. Each run changes projects/notes.txt, adds reports/q3.csv when it
# is missing and deletes reports/q2.csv. Run it as root.
set -eu
DATA=/srv/data
STATE_DIR=/opt/linux-labs/state/files-07

if [ "$(id -u)" -ne 0 ]; then
	echo "lab-churn: run it as root" >&2
	exit 1
fi
if [ ! -d "$DATA" ] || [ ! -f "$STATE_DIR/flags" ]; then
	echo "lab-churn: lab files-07 is not started" >&2
	exit 1
fi

now=$(date '+%Y-%m-%d %H:%M:%S')
printf 'Updated by lab-churn on %s.\n' "$now" >> "$DATA/projects/notes.txt"
echo "changed $DATA/projects/notes.txt"
if [ ! -e "$DATA/reports/q3.csv" ]; then
	printf 'month,tickets\njul,44\naug,40\nsep,46\n' > "$DATA/reports/q3.csv"
	chown snapops:snapteam "$DATA/reports/q3.csv"
	chmod 0640 "$DATA/reports/q3.csv"
	restorecon "$DATA/reports/q3.csv" >/dev/null 2>&1 || true
	echo "added $DATA/reports/q3.csv"
fi
if [ -e "$DATA/reports/q2.csv" ]; then
	rm -f "$DATA/reports/q2.csv"
	echo "deleted $DATA/reports/q2.csv"
fi
echo "$now" >> "$STATE_DIR/churn"
chmod 0644 "$STATE_DIR/churn"
PROGRAM
chmod 0755 /usr/local/sbin/lab-churn
restorecon /usr/local/sbin/lab-churn >/dev/null 2>&1 || true
