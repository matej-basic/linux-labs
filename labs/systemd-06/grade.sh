#!/bin/bash
# systemd-06 grader
source /opt/linux-labs/lib/grading.sh

LAB=systemd-06
STATE_FILE=/opt/linux-labs/state/$LAB
ACCOUNT=labjobs
BATCH=/usr/local/bin/lab-batch

grade_begin systemd-06
grade_require_state systemd-06 "$STATE_FILE"

user=$(awk '$1 == "owner" { print $2 }' "$STATE_FILE")
user=${user:-${LAB_USER:-student}}

recorded_pid() {
	awk -v n="$1" '$1 == n { print $2 }' "$STATE_FILE"
}

# The worker still runs as the process setup.sh started: the recorded PID
# has the worker's name and belongs to labjobs
original_runs() {
	local pid
	pid=$(recorded_pid "$1")
	[ -n "$pid" ] || return 1
	[ "$(cat "/proc/$pid/comm" 2>/dev/null)" = "$1" ] || return 1
	[ "$(ps -o user= -p "$pid" 2>/dev/null | tr -d ' ')" = "$ACCOUNT" ]
}

# The original process has the nice value
original_nice() {
	local pid
	original_runs "$1" || return 1
	pid=$(recorded_pid "$1")
	[ "$(ps -o ni= -p "$pid" 2>/dev/null | tr -d ' ')" = "$2" ]
}

# No process with this name exists any more
not_running() {
	! pgrep -x "$1"
}

# PIDs of lab-batch processes of a user: the script itself, or a shell
# that runs it (bash /usr/local/bin/lab-batch)
batch_pids() {
	local pid args
	for pid in $(pgrep -u "$1"); do
		if [ "$(cat "/proc/$pid/comm" 2>/dev/null)" = lab-batch ]; then
			echo "$pid"
			continue
		fi
		args=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)
		case $args in
		bash\ $BATCH* | sh\ $BATCH* | */bash\ $BATCH* | */sh\ $BATCH*)
			echo "$pid"
			;;
		esac
	done
}

batch_runs() {
	[ -n "$(batch_pids "$user")" ]
}

batch_nice() {
	local pid
	for pid in $(batch_pids "$user"); do
		[ "$(ps -o ni= -p "$pid" 2>/dev/null | tr -d ' ')" = 10 ] && return 0
	done
	return 1
}

criterion "Original lab-report process is still running" original_runs lab-report
criterion "lab-report has the nice value 15" original_nice lab-report 15
criterion "Original lab-ingest process is still running" original_runs lab-ingest
criterion "lab-ingest has the nice value -5" original_nice lab-ingest -5
criterion "lab-stale is no longer running" not_running lab-stale
criterion "lab-hung is no longer running" not_running lab-hung
criterion "lab-batch is running as $user" batch_runs
criterion "lab-batch of $user has the nice value 10" batch_nice
grade_end
