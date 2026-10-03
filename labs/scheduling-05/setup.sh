#!/bin/bash
# scheduling-05 setup: three cron jobs that should each append a line to
# their own log in /var/log/cronlab every minute, and none of them runs:
#   - /etc/cron.d/lab-backup has mode 0666, so crond skips the file
#     (BAD FILE MODE in /var/log/cron)
#   - /etc/cron.d/lab-cleanup has no user field, so crond takes the
#     command path for the user name (getpwnam() failed)
#   - the crontab of the user reports calls lab-report by its bare name,
#     which is not in the PATH of cron jobs, and passes $(date +%F) with
#     an unescaped %, so the command ends at the % and the redirection
#     never happens
# The helper /usr/local/sbin/lab-report prints the date and time, its
# name with the user that runs it, and its arguments.
#
# The first run records the state of crond. Every run writes the
# checksum of the helper to the state file. Prints nothing on success.
set -eu

LAB=scheduling-05
STATE_DIR=/opt/linux-labs/state
STATE_FILE=$STATE_DIR/$LAB
HELPER=/usr/local/sbin/lab-report
LOGDIR=/var/log/cronlab
USR=reports

fail() {
	echo "Error: $*" >&2
	exit 1
}

rpm -q cronie >/dev/null 2>&1 || fail "the package cronie is not installed."

# First run only: the state of crond before the lab
if [ ! -r "$STATE_FILE" ]; then
	mkdir -p "$STATE_DIR"
	en=no
	ac=no
	systemctl is-enabled --quiet crond 2>/dev/null && en=yes
	systemctl is-active --quiet crond 2>/dev/null && ac=yes
	printf 'crond_was_enabled=%s\ncrond_was_active=%s\n' "$en" "$ac" \
		> "$STATE_FILE.tmp"
	chmod 0644 "$STATE_FILE.tmp"
	mv "$STATE_FILE.tmp" "$STATE_FILE"
fi

# Remove what an earlier run or the solution left behind
rm -f /etc/cron.d/lab-backup /etc/cron.d/lab-cleanup
if id "$USR" >/dev/null 2>&1; then
	crontab -u "$USR" -r >/dev/null 2>&1 || true
	pkill -KILL -u "$USR" 2>/dev/null || true
	userdel -r "$USR" >/dev/null 2>&1 || fail "cannot remove the old user $USR."
fi
rm -f /var/spool/cron/"$USR"
rm -rf "$LOGDIR"

useradd -m "$USR" >/dev/null || fail "cannot create the user $USR."

cat > "$HELPER" <<'SH'
#!/bin/bash
# lab-report: print one report line with the date and time, the user
# that runs it and the arguments.
printf '%s lab-report[%s] %s\n' "$(date '+%F %T')" "$(id -un)" "$*"
SH
chown root:root "$HELPER"
chmod 0755 "$HELPER"
restorecon "$HELPER" >/dev/null 2>&1 || true

mkdir -m 0755 "$LOGDIR"
install -m 0644 -o root -g root /dev/null "$LOGDIR/backup.log"
install -m 0644 -o root -g root /dev/null "$LOGDIR/cleanup.log"
install -m 0644 -o "$USR" -g "$USR" /dev/null "$LOGDIR/daily.log"
restorecon -R "$LOGDIR" >/dev/null 2>&1 || true

cat > /etc/cron.d/lab-backup <<'CRON'
# Backup report, every minute
* * * * * root /usr/local/sbin/lab-report backup >> /var/log/cronlab/backup.log 2>&1
CRON
chmod 0666 /etc/cron.d/lab-backup

cat > /etc/cron.d/lab-cleanup <<'CRON'
# Cleanup report, every minute
* * * * * /usr/local/sbin/lab-report cleanup >> /var/log/cronlab/cleanup.log 2>&1
CRON
chmod 0644 /etc/cron.d/lab-cleanup
restorecon /etc/cron.d/lab-backup /etc/cron.d/lab-cleanup >/dev/null 2>&1 || true

crontab -u "$USR" - <<'CRON'
# Daily report for the reports team, every minute
* * * * * lab-report $(date +%F) >> /var/log/cronlab/daily.log 2>&1
CRON

systemctl enable --now crond >/dev/null 2>&1 || fail "cannot start crond."

# The checksum the grader compares
{
	grep -v '^sum_helper=' "$STATE_FILE"
	echo "sum_helper=$(sha256sum "$HELPER" | awk '{ print $1 }')"
} > "$STATE_FILE.tmp"
chmod 0644 "$STATE_FILE.tmp"
mv "$STATE_FILE.tmp" "$STATE_FILE"
exit 0
