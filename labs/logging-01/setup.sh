#!/bin/bash
# logging-01 setup: writes eight tagged test entries to the journal and
# creates an empty ~/journal-lab for the lab user. The run id and the
# owner go into the state file for the grader. Prints nothing on success.
set -eu

STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/logging-01"
TAG=labjournal

if ! systemctl is-active --quiet systemd-journald; then
	echo "Error: systemd-journald is not running" >&2
	exit 1
fi
if ! command -v systemd-cat >/dev/null 2>&1; then
	echo "Error: systemd-cat is not installed" >&2
	exit 1
fi

# Lab owner: the task user (LAB_USER), else "student". If that user does
# not exist, use the first regular user (UID >= 1000), else root.
owner="${LAB_USER:-student}"
if ! id "$owner" &>/dev/null; then
	owner=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 { print $1; exit }')
	owner="${owner:-root}"
fi
home=$(getent passwd "$owner" | cut -d: -f6)
dir="$home/journal-lab"

# Reset the working directory
rm -rf "$dir"
mkdir -p "$dir"
chown "$owner": "$dir"
chmod 755 "$dir"

# Write the test entries; the run id makes this run's messages unique.
# The journal keeps entries of earlier runs, the grader tells them apart.
rid=$(date +%s)
emit() {
	printf '%s\n' "level=$2 $rid $3" | systemd-cat -t "$TAG" -p "$1"
}
emit info info "user session opened"
emit warning warning "certificate expires in 14 days"
emit err err "backup job failed"
emit notice notice "configuration reloaded"
emit crit crit "power supply redundancy lost"
emit warning warning "disk usage above 80 percent"
emit err err "mail queue is not draining"
emit info info "health check completed"

# Wait until the last entry is readable
journalctl --sync >/dev/null 2>&1 || true
for _ in $(seq 1 20); do
	if journalctl -t "$TAG" -o cat --no-pager 2>/dev/null | grep -qF "level=info $rid health check completed"; then
		break
	fi
	sleep 0.5
done
if ! journalctl -t "$TAG" -o cat --no-pager 2>/dev/null | grep -qF "level=info $rid health check completed"; then
	echo "Error: the test entries did not reach the journal" >&2
	exit 1
fi

# Record owner, directory and run id for the grader
mkdir -p "$STATE_DIR"
{
	echo "OWNER=$owner"
	echo "DIR=$dir"
	echo "RID=$rid"
} > "$STATE_FILE"
chmod 644 "$STATE_FILE"
