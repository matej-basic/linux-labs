#!/bin/bash
# systemd-06 cleanup: stop the transient units, end every lab process
# (also lab-batch started by the student), undo an enable-linger of the
# task user, remove the scripts, the account labjobs and the state file.
# Safe when the lab was never started.
LAB=systemd-06
STATE_FILE=/opt/linux-labs/state/$LAB
ACCOUNT=labjobs
BIN=/usr/local/bin
NAMES="lab-report lab-ingest lab-stale lab-hung lab-batch"
rc=0

owner=$(awk '$1 == "owner" { print $2 }' "$STATE_FILE" 2>/dev/null)
linger=$(awk '$1 == "linger" { print $2 }' "$STATE_FILE" 2>/dev/null)

for name in $NAMES; do
	systemctl kill --signal=SIGKILL "$name.service" >/dev/null 2>&1 || true
	systemctl stop "$name.service" >/dev/null 2>&1 || true
	systemctl reset-failed "$name.service" >/dev/null 2>&1 || true
done

# pkill never matches itself; -x matches the process name exactly, -f
# also catches a script started through a shell (bash lab-batch)
lab_processes() {
	local name
	for name in $NAMES; do
		pgrep -x "$name"
	done
	pgrep -f "^([^ ]*/)?(ba)?sh $BIN/lab-(report|ingest|stale|hung|batch)( |\$)"
	pgrep -u "$ACCOUNT" 2>/dev/null
}
# The lab processes and their children (the sleep of a worker loop)
lab_tree() {
	local pids
	pids=$(lab_processes | sort -u | paste -sd, -)
	[ -n "$pids" ] || return 0
	echo "$pids" | tr , '\n'
	pgrep -P "$pids"
}
for _ in $(seq 1 20); do
	pids=$(lab_tree | sort -u)
	[ -n "$pids" ] || break
	# shellcheck disable=SC2086 # one PID per word
	kill -KILL $pids 2>/dev/null || true
	sleep 0.25
done
if [ -n "$(lab_processes)" ]; then
	echo "$LAB: some lab processes are still running" >&2
	rc=1
fi

# Lingering is needed for a lab-batch started with systemd-run --user
if [ -n "$owner" ] && [ "$linger" = no ] &&
	[ -e "/var/lib/systemd/linger/$owner" ]; then
	loginctl disable-linger "$owner" >/dev/null 2>&1 || rc=1
fi

rm -f "$BIN"/lab-report "$BIN"/lab-ingest "$BIN"/lab-stale \
	"$BIN"/lab-hung "$BIN"/lab-batch
if id "$ACCOUNT" >/dev/null 2>&1; then
	userdel "$ACCOUNT" >/dev/null 2>&1 || rc=1
fi
if getent group "$ACCOUNT" >/dev/null 2>&1; then
	groupdel "$ACCOUNT" >/dev/null 2>&1 || rc=1
fi
rm -f "$STATE_FILE"
exit "$rc"
