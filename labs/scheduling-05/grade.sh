#!/bin/bash
# scheduling-05 grader
source /opt/linux-labs/lib/grading.sh

LAB=scheduling-05
STATE_FILE=/opt/linux-labs/state/$LAB
HELPER=/usr/local/sbin/lab-report
LOGDIR=/var/log/cronlab
USR=reports
# A line counts as recent when its time stamp is at most this old
RECENT=180
# How long to wait for the next run when a recent line is missing
WAIT=75

state_value() {
	sed -n "s/^$1=//p" "$STATE_FILE" 2>/dev/null | head -n 1
}

# Job lines of a crontab on stdin: no comments, blank lines or variable
# settings
job_lines() {
	grep -Ev '^[[:space:]]*(#|$)|^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=' || true
}

# cron_d_safe <file>: the file is a regular file owned by root that the
# group and others cannot write
cron_d_safe() {
	[ -f "$1" ] && [ ! -L "$1" ] &&
		[ "$(stat -c %u "$1" 2>/dev/null)" = 0 ] &&
		[ -z "$(find "$1" -maxdepth 0 -perm /022 2>/dev/null)" ]
}

# cron_d_job <file>: at least one job line, and every job line runs
# lab-report every minute as root
cron_d_job() {
	local lines
	[ -f "$1" ] || return 1
	lines=$(job_lines < "$1")
	[ -n "$lines" ] || return 1
	printf '%s\n' "$lines" | awk '
		!(($1 == "*" || $1 == "*/1") && $2 == "*" && $3 == "*" &&
		  $4 == "*" && $5 == "*" && $6 == "root" &&
		  $7 ~ /^(\/usr\/local\/sbin\/)?lab-report$/) { bad = 1 }
		END { exit bad }'
}

# The crontab of reports has a job that runs lab-report every minute
user_job() {
	crontab -u "$USR" -l 2>/dev/null | job_lines | awk '
		$6 ~ /^(\/usr\/local\/sbin\/)?lab-report$/ {
			n++
			if (!(($1 == "*" || $1 == "*/1") && $2 == "*" &&
			      $3 == "*" && $4 == "*" && $5 == "*")) bad = 1
		}
		END { exit (n == 0 || bad) }'
}

helper_unchanged() {
	local want
	want=$(state_value sum_helper)
	[ -n "$want" ] && [ -f "$HELPER" ] &&
		[ "$(sha256sum "$HELPER" 2>/dev/null | awk '{ print $1 }')" = "$want" ]
}

crond_ok() {
	systemctl is-enabled --quiet crond && systemctl is-active --quiet crond
}

# recent_lines <log> <user>: the lines of lab-report run by <user> with
# a time stamp from the last RECENT seconds
recent_lines() {
	[ -f "$1" ] || return 0
	tail -n 500 "$1" 2>/dev/null | awk -v now="$(date +%s)" -v u="$2" \
		-v max="$RECENT" '
		$1 ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/ &&
		$2 ~ /^[0-9][0-9]:[0-9][0-9]:[0-9][0-9]$/ &&
		$3 == "lab-report[" u "]" {
			d = $1 " " $2
			gsub(/[-:]/, " ", d)
			t = mktime(d)
			if (t >= now - max && t <= now + 60) print
		}'
}

# recent_job <log> <user> <argument>: a recent line of that user with
# exactly that argument
recent_job() {
	recent_lines "$1" "$2" | awk -v a="$3" 'NF == 4 && $4 == a { f = 1 } END { exit !f }'
}

recent_daily_by_user() {
	[ -n "$(recent_lines "$LOGDIR/daily.log" "$USR")" ]
}

# The latest recent line of reports has the current date as its only
# argument, in the form YYYY-MM-DD
recent_daily_date() {
	recent_lines "$LOGDIR/daily.log" "$USR" | tail -n 1 |
		awk 'NF == 4 && $4 == $1 { f = 1 } END { exit !f }'
}

all_recent() {
	recent_job "$LOGDIR/backup.log" root backup &&
		recent_job "$LOGDIR/cleanup.log" root cleanup &&
		recent_daily_date
}

grade_begin scheduling-05
grade_require_state scheduling-05 "$STATE_FILE"

criterion "crond is enabled and running" crond_ok
criterion "/etc/cron.d/lab-backup: owner root, no group/other write" \
	cron_d_safe /etc/cron.d/lab-backup
criterion "/etc/cron.d/lab-backup runs lab-report every minute as root" \
	cron_d_job /etc/cron.d/lab-backup
criterion "/etc/cron.d/lab-cleanup: owner root, no group/other write" \
	cron_d_safe /etc/cron.d/lab-cleanup
criterion "/etc/cron.d/lab-cleanup runs lab-report every minute as root" \
	cron_d_job /etc/cron.d/lab-cleanup
criterion "The crontab of $USR runs lab-report every minute" user_job
criterion "$HELPER is unchanged" helper_unchanged

# Give the jobs one more run when a recent line is missing
end=$((SECONDS + WAIT))
while ! all_recent && [ "$SECONDS" -lt "$end" ]; do
	sleep 5
done

criterion "$LOGDIR/backup.log has a recent line by root" \
	recent_job "$LOGDIR/backup.log" root backup
criterion "$LOGDIR/cleanup.log has a recent line by root" \
	recent_job "$LOGDIR/cleanup.log" root cleanup
criterion "$LOGDIR/daily.log has a recent line by $USR" recent_daily_by_user
criterion "The recent line in daily.log ends with today's date" \
	recent_daily_date
grade_end
