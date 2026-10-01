#!/bin/bash
# scheduling-03 grader
source /opt/linux-labs/lib/grading.sh

STATE_DIR=/opt/linux-labs/state/scheduling-03
ANACRONTAB=/etc/anacrontab
TIMER=/etc/systemd/system/persistent-timer.timer
PATH_VALUE=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

grade_begin scheduling-03
grade_require_state scheduling-03 "$STATE_DIR/started"

# Run a script once (as root, 10 s limit) and check that its log file grows
# and the new line holds a digit-bearing timestamp.
script_logs() {
	local script="$1" log="$2" before after
	[ -x "$script" ] || return 1
	before=$(wc -l < "$log" 2>/dev/null || echo 0)
	LOGFILE=/var/log/env-task.log timeout 10 "$script" >/dev/null 2>&1 </dev/null
	after=$(wc -l < "$log" 2>/dev/null || echo 0)
	[ "$after" -gt "$before" ] && tail -n 1 "$log" | grep -q '[0-9]'
}
anacron_script_logs() { script_logs /usr/local/bin/anacron-task.sh /var/log/anacron-task.log; }
timer_script_logs() { script_logs /usr/local/bin/persistent-task.sh /var/log/persistent-task.log; }
env_script_logs() { script_logs /usr/local/bin/env-task.sh /var/log/env-task.log; }

anacron_job() {
	grep -Eq '^1[[:space:]]+5[[:space:]]+anacron_lab[[:space:]]+/usr/local/bin/anacron-task\.sh[[:space:]]*$' "$ANACRONTAB"
}

service_runs_script() {
	[ "$(systemctl show -p Type --value persistent-timer.service 2>/dev/null)" = oneshot ] || return 1
	systemctl show -p ExecStart --value persistent-timer.service 2>/dev/null |
		grep -q 'path=/usr/local/bin/persistent-task\.sh ;'
}

timer_boot_30s() {
	systemctl show -p TimersMonotonic --value persistent-timer.timer 2>/dev/null |
		grep -q 'OnBootUSec=30s'
}

timer_active_1h() {
	systemctl show -p TimersMonotonic --value persistent-timer.timer 2>/dev/null |
		grep -q 'OnUnitActiveUSec=1h'
}

timer_persistent() {
	[ "$(systemctl show -p Persistent --value persistent-timer.timer 2>/dev/null)" = yes ]
}

timer_in_timers_target() {
	grep -Eq '^WantedBy=([^#]*[[:space:]])?timers\.target([[:space:]]|$)' "$TIMER" 2>/dev/null
}

CRON_FILE=$(mktemp)
trap 'rm -f "$CRON_FILE"' EXIT
crontab -l -u root > "$CRON_FILE" 2>/dev/null

# Line number of the first line matching a pattern, empty when absent
cron_line() { grep -nE "$1" "$CRON_FILE" | head -n 1 | cut -d: -f1; }

# The job line: minute 0, every sixth hour, daily, runs the script
JOB_RE='^0[[:space:]]+(\*/6|0-23/6|0,6,12,18)[[:space:]]+\*[[:space:]]+\*[[:space:]]+\*[[:space:]]+/usr/local/bin/env-task\.sh([[:space:]].*)?$'

cron_var() {
	grep -Eq "^$1[[:space:]]*=[[:space:]]*[\"']?$2[\"']?[[:space:]]*$" "$CRON_FILE"
}

cron_job_exists() { [ -n "$(cron_line "$JOB_RE")" ]; }

cron_vars_before_job() {
	local job v first
	job=$(cron_line "$JOB_RE")
	[ -n "$job" ] || return 1
	for v in SHELL PATH LOGFILE; do
		first=$(cron_line "^${v}[[:space:]]*=")
		[ -n "$first" ] && [ "$first" -lt "$job" ] || return 1
	done
}

criterion "Script /usr/local/bin/anacron-task.sh logs a timestamp" anacron_script_logs
criterion "Anacron job anacron_lab runs daily with a 5 minute delay" anacron_job
criterion "Script /usr/local/bin/persistent-task.sh logs a timestamp" timer_script_logs
criterion "Service persistent-timer.service is oneshot and runs script" service_runs_script
criterion "Timer persistent-timer.timer starts 30s after boot" timer_boot_30s
criterion "Timer persistent-timer.timer repeats 1h after each run" timer_active_1h
criterion "Timer persistent-timer.timer has Persistent=true" timer_persistent
criterion "Timer persistent-timer.timer is installed in timers.target" timer_in_timers_target
criterion "Timer persistent-timer.timer is enabled" systemctl is-enabled --quiet persistent-timer.timer
criterion "Timer persistent-timer.timer is running" systemctl is-active --quiet persistent-timer.timer
criterion "Script /usr/local/bin/env-task.sh logs a timestamp" env_script_logs
criterion "Root crontab sets SHELL=/bin/bash" cron_var SHELL /bin/bash
criterion "Root crontab sets the standard system PATH" cron_var PATH "$PATH_VALUE"
criterion "Root crontab sets LOGFILE=/var/log/env-task.log" cron_var LOGFILE /var/log/env-task.log
criterion "Root crontab runs env-task.sh every 6 hours" cron_job_exists
criterion "Root crontab defines the variables before the job" cron_vars_before_job
grade_end
