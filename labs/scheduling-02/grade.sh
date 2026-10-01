#!/bin/bash
# scheduling-02 grader
source /opt/linux-labs/lib/grading.sh

SCRIPT=/usr/local/bin/lab-task.sh
LOG=/var/log/lab-task.log
SERVICE=lab-task.service
TIMER=lab-task.timer

# Service property "name" equals value
service_prop() {
	[ "$(systemctl show -p "$1" --value "$SERVICE" 2>/dev/null)" = "$2" ]
}

# ExecStart of the service runs the script
service_execstart() {
	systemctl show -p ExecStart --value "$SERVICE" 2>/dev/null |
		grep -q "path=$SCRIPT ;"
}

# The timer has a monotonic trigger with the given name and value
timer_trigger() {
	systemctl show -p TimersMonotonic --value "$TIMER" 2>/dev/null |
		grep -Eq "$1=$2 ;"
}

# The timer is wanted by timers.target through an enablement symlink
timer_installed() {
	[ -e "/etc/systemd/system/timers.target.wants/$TIMER" ]
}

# Run the service once: it must succeed and add a timestamped line to the log
service_logs_run() {
	local before after line
	before=$(wc -l < "$LOG" 2>/dev/null || echo 0)
	systemctl start "$SERVICE" &>/dev/null || return 1
	after=$(wc -l < "$LOG" 2>/dev/null || echo 0)
	[ "$after" -gt "$before" ] || return 1
	line=$(tail -n 1 "$LOG")
	echo "$line" | grep -Eq '[0-9]{1,2}:[0-9]{2}|20[0-9]{2}'
}

grade_begin scheduling-02

criterion "Script $SCRIPT exists and is executable" test -x "$SCRIPT"
criterion "File /etc/systemd/system/$SERVICE exists" test -f "/etc/systemd/system/$SERVICE"
criterion "Service is of type oneshot" service_prop Type oneshot
criterion "Service ExecStart runs $SCRIPT" service_execstart
criterion "File /etc/systemd/system/$TIMER exists" test -f "/etc/systemd/system/$TIMER"
criterion "Timer has OnBootSec=1min" timer_trigger OnBootUSec 1min
criterion "Timer has OnUnitActiveSec=10min" timer_trigger OnUnitActiveUSec 10min
criterion "Timer is installed into timers.target" timer_installed
criterion "Timer is enabled" systemctl is-enabled --quiet "$TIMER"
criterion "Timer is active" systemctl is-active --quiet "$TIMER"
criterion "Service run appends a timestamped line to $LOG" service_logs_run
grade_end
