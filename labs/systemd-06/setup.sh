#!/bin/bash
# systemd-06 setup: create the service account labjobs and five small
# worker scripts in /usr/local/bin, start four of them as transient
# system units owned by labjobs (so that they outlive the SSH session of
# labctl) and record their PIDs for the grader. lab-batch is installed
# but not started; the student starts it. Prints nothing on success.
set -eu

LAB=systemd-06
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
ACCOUNT=labjobs
BIN=/usr/local/bin
WORKERS="lab-report lab-ingest lab-stale lab-hung"

fail() {
	echo "$LAB: $*" >&2
	exit 1
}

for cmd in systemd-run pgrep pkill ps renice nohup; do
	command -v "$cmd" >/dev/null 2>&1 || fail "the command $cmd is missing"
done

# Task user, as in files-04
owner="${LAB_USER:-student}"
if ! id "$owner" &>/dev/null; then
	owner=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 { print $1; exit }')
	[ -n "$owner" ] || fail "no regular user for the task"
fi

# Remove what an earlier run or the solution left behind
bash "$(dirname "$0")/cleanup.sh" >/dev/null 2>&1 || true

# Lingering of the task user before the lab, so that cleanup.sh can undo
# an enable-linger of the student
linger=no
[ -e "/var/lib/systemd/linger/$owner" ] && linger=yes

useradd -r -M -d / -s /sbin/nologin -c "Lab batch jobs" "$ACCOUNT" ||
	fail "cannot create the user $ACCOUNT"

# Mostly idle workers: a loop of short sleeps. lab-hung ignores SIGTERM;
# an ignored signal stays ignored in its sleep children as well.
write_worker() {
	local name=$1 extra=$2
	cat > "$BIN/$name" <<SCRIPT
#!/bin/bash
# $name: worker process of lab $LAB
$extra
while :; do
	sleep 10
done
SCRIPT
	chmod 755 "$BIN/$name"
	restorecon "$BIN/$name" 2>/dev/null || true
}
write_worker lab-report ""
write_worker lab-ingest ""
write_worker lab-stale ""
write_worker lab-hung "trap '' TERM"
write_worker lab-batch ""

# Start the workers as transient units and wait until each one runs
# its script, so that the recorded PID belongs to the named process
pids=""
for name in $WORKERS; do
	systemd-run --quiet --unit="$name" --description="Lab worker $name" \
		--uid="$ACCOUNT" --gid="$ACCOUNT" --property=Restart=no \
		"$BIN/$name" >/dev/null 2>&1 || fail "cannot start the unit $name"
	pid=""
	for _ in $(seq 1 50); do
		pid=$(systemctl show -p MainPID --value "$name.service" 2>/dev/null || true)
		if [ -n "$pid" ] && [ "$pid" != 0 ] &&
			[ "$(cat "/proc/$pid/comm" 2>/dev/null)" = "$name" ]; then
			break
		fi
		pid=""
		sleep 0.1
	done
	[ -n "$pid" ] || fail "the worker $name did not start"
	pids="$pids$name $pid
"
done

mkdir -p "$STATE_DIR"
{
	echo "owner $owner"
	echo "linger $linger"
	printf '%s' "$pids"
} > "$STATE_FILE"
chmod 644 "$STATE_FILE"
