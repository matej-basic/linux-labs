#!/bin/bash
# Runs a lab script on a server target (description.txt "target: servera",
# serverb or serverc). labctl sends a bundle with this file, the lab
# directory, the library and the workstation's prompt script over SSH and
# runs it there as root (ssh <SSH_USER>@<target> sudo -n bash -s). It is
# not meant to be run by hand.
#
# Usage: target-run.sh <bundle> <start|grade|reset> <lab> <task user> <colour>
#
#   <bundle>     temporary directory with labs/<lab>/, lib/ and profile.sh
#   <task user>  exported to the lab scripts as LAB_USER
#   <colour>     exported as LABCTL_COLOR (1: colour the grade results)
#
# The working copy of a started lab lives in /var/lib/linux-labs (labs/<lab>
# and lib) from labctl start until labctl reset. Lab scripts source
# /opt/linux-labs/lib/<file>; the copy points those lines at
# /var/lib/linux-labs/lib/<file>. Lab state stays where the lab writes it
# (/opt/linux-labs/state/<lab> on the target).
#
#   start  fresh copy, setup.sh; on success the prompt script goes to
#          /etc/profile.d/labctl.sh and the lab name to
#          /opt/linux-labs/.current_lab. A failed setup removes the copy.
#   grade  grade.sh from the working copy, or from a temporary copy when
#          the lab is not started on this target.
#   reset  fresh copy, cleanup.sh, then the copy and the marker are removed
#          (also when cleanup.sh fails). The prompt script stays.
#
# The exit status is the status of the lab script, or 1 when the copy
# fails.

set -u

BUNDLE="$1"
MODE="$2"
LAB="$3"
TASK_USER="$4"
COLOUR="$5"

BASE=/var/lib/linux-labs
MARKER=/opt/linux-labs/.current_lab
PROFILE=/etc/profile.d/labctl.sh

host=$(uname -n)
host="${host%%.*}"

# install_copy <dir>: copy labs/<lab> and lib from the bundle to <dir>
install_copy() {
	local dir="$1"
	mkdir -p "$dir/labs" || return 1
	chmod 0755 "$dir" "$dir/labs" || return 1
	rm -rf "${dir:?}/labs/$LAB" "${dir:?}/lib" || return 1
	cp -R "$BUNDLE/labs/$LAB" "$dir/labs/$LAB" || return 1
	cp -R "$BUNDLE/lib" "$dir/lib" || return 1
	rm -f "$dir/labs/$LAB/solve.sh" "$dir/labs/$LAB/known-issues.md"
	sed -i "s#/opt/linux-labs/lib/#$dir/lib/#g" "$dir/labs/$LAB"/*.sh || return 1
	# Same modes as the installed RPM, so a script may run a sibling directly
	chmod 0755 "$dir/labs/$LAB"/*.sh || return 1
	if command -v restorecon >/dev/null 2>&1; then
		restorecon -R "$dir" >/dev/null 2>&1
	fi
	return 0
}

# run_script <dir> <script>: run a lab script as root with the task user
run_script() {
	(
		cd / || exit 1
		LAB_USER="$TASK_USER" LABCTL_COLOR="$COLOUR" bash "$1/labs/$LAB/$2"
	) </dev/null
}

copy_failed() {
	echo "labctl: cannot copy lab $LAB to $1 on $host" >&2
}

case "$MODE" in
	start)
		if ! install_copy "$BASE"; then
			copy_failed "$BASE"
			rm -rf "$BASE"
			exit 1
		fi
		run_script "$BASE" setup.sh
		rc=$?
		if [ "$rc" -ne 0 ]; then
			rm -rf "$BASE"
			exit "$rc"
		fi
		if [ -f "$BUNDLE/profile.sh" ]; then
			install -m 0644 "$BUNDLE/profile.sh" "$PROFILE" || exit 1
		fi
		mkdir -p "${MARKER%/*}" || exit 1
		echo "$LAB" > "$MARKER" || exit 1
		chmod 0644 "$MARKER"
		if command -v restorecon >/dev/null 2>&1; then
			restorecon "$PROFILE" "$MARKER" >/dev/null 2>&1
		fi
		exit 0
		;;
	grade)
		if [ -f "$BASE/labs/$LAB/grade.sh" ]; then
			run_script "$BASE" grade.sh
			exit $?
		fi
		if ! install_copy "$BUNDLE/run"; then
			copy_failed "$BUNDLE/run"
			exit 1
		fi
		run_script "$BUNDLE/run" grade.sh
		exit $?
		;;
	reset)
		rc=1
		if install_copy "$BASE"; then
			run_script "$BASE" cleanup.sh
			rc=$?
		else
			copy_failed "$BASE"
		fi
		rm -rf "$BASE"
		rm -f "$MARKER"
		# Remove the directories the lab created, only when they are empty
		rmdir /opt/linux-labs/state 2>/dev/null
		rmdir /opt/linux-labs 2>/dev/null
		exit "$rc"
		;;
	*)
		echo "target-run.sh: unknown mode: $MODE" >&2
		exit 2
		;;
esac
