#!/bin/bash
# systemd-02 grader
source /opt/linux-labs/lib/grading.sh

UNIT=custom-app.service
SCRIPT=/opt/custom-app.sh
LOG=/var/log/custom-app.log

grade_begin systemd-02

# The unit runs the script in the foreground (Type=simple)
unit_runs_script() {
	[ "$(systemctl show -p Type --value "$UNIT" 2>/dev/null)" = simple ] || return 1
	systemctl show -p ExecStart "$UNIT" 2>/dev/null | grep -q "path=$SCRIPT ;"
}

# The unit file has an [Install] section that targets multi-user.target
unit_in_multi_user() {
	systemctl show -p WantedBy --value "$UNIT" 2>/dev/null | grep -qw multi-user.target
}

# The log is non-empty and holds text written by the script
log_has_output() {
	[ -s "$LOG" ]
}

criterion "Script $SCRIPT exists and is executable" test -x "$SCRIPT"
criterion "Unit file /etc/systemd/system/$UNIT exists" test -f "/etc/systemd/system/$UNIT"
criterion "$UNIT is Type=simple and runs $SCRIPT" unit_runs_script
criterion "$UNIT is installed into multi-user.target" unit_in_multi_user
criterion "$UNIT is enabled" systemctl is-enabled --quiet "$UNIT"
criterion "$UNIT is running" systemctl is-active --quiet "$UNIT"
criterion "Log file $LOG contains output" log_has_output
grade_end
