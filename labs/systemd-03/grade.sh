#!/bin/bash
# systemd-03 grader
source /opt/linux-labs/lib/grading.sh

SCRIPT=/opt/lab-worker.sh
LOG=/var/lib/lab-worker/execution.log
UNIT_DIR=/etc/systemd/system

# Unit file exists in /etc/systemd/system and systemd has loaded it
unit_loaded() {
	[ -f "$UNIT_DIR/$1" ] || return 1
	[ "$(systemctl show -p FragmentPath --value "$1" 2>/dev/null)" = "$UNIT_DIR/$1" ]
}

# Loaded service is Type=oneshot and runs the worker script
oneshot_runs_worker() {
	[ "$(systemctl show -p Type --value "$1" 2>/dev/null)" = oneshot ] || return 1
	systemctl show -p ExecStart "$1" 2>/dev/null | grep -Eq "path=$SCRIPT ;"
}

timer_boot_1min() {
	systemctl show -p TimersMonotonic lab-timer.timer 2>/dev/null | grep -Eq 'OnBootUSec=1min[ ;]'
}

timer_active_5min() {
	systemctl show -p TimersMonotonic lab-timer.timer 2>/dev/null | grep -Eq 'OnUnitActiveUSec=5min[ ;]'
}

timer_targets_service() {
	[ "$(systemctl show -p Unit --value lab-timer.timer 2>/dev/null)" = lab-timer.service ]
}

# WantedBy=timers.target: enabled through the symlink in timers.target.wants
timer_in_timers_target() {
	[ -L "$UNIT_DIR/timers.target.wants/lab-timer.timer" ] || return 1
	grep -Eq '^WantedBy=.*timers\.target' "$UNIT_DIR/lab-timer.timer"
}

log_has_timestamp() {
	grep -Eq '[0-9]{2}:[0-9]{2}:[0-9]{2}' "$LOG"
}

grade_begin systemd-03
criterion "Script $SCRIPT exists and is executable" test -x "$SCRIPT"
criterion "Unit lab-worker.service is installed and loaded" unit_loaded lab-worker.service
criterion "lab-worker.service is oneshot and runs $SCRIPT" oneshot_runs_worker lab-worker.service
criterion "Unit lab-timer.service is installed and loaded" unit_loaded lab-timer.service
criterion "lab-timer.service is oneshot and runs $SCRIPT" oneshot_runs_worker lab-timer.service
criterion "Unit lab-timer.timer is installed and loaded" unit_loaded lab-timer.timer
criterion "lab-timer.timer starts lab-timer.service" timer_targets_service
criterion "lab-timer.timer fires 1 minute after boot" timer_boot_1min
criterion "lab-timer.timer repeats 5 minutes after last activation" timer_active_5min
criterion "lab-timer.timer is installed in timers.target" timer_in_timers_target
criterion "lab-timer.timer is enabled" systemctl is-enabled --quiet lab-timer.timer
criterion "lab-timer.timer is active" systemctl is-active --quiet lab-timer.timer
criterion "Log $LOG has an entry with a time" log_has_timestamp
grade_end
