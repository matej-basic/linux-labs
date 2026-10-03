#!/bin/bash
# systemd-08 grader. Reads systemctl show and /proc only, never the
# cgroup file system, which is v1 on EL8 and v2 on EL9.
source /opt/linux-labs/lib/grading.sh

UNIT=labapp.service
VENDOR=/usr/lib/systemd/system/$UNIT
DROPIN_DIR=/etc/systemd/system/$UNIT.d
STATE_FILE=/opt/linux-labs/state/systemd-08

grade_begin systemd-08
grade_require_state systemd-08 "$STATE_FILE"
sum=$(head -n 1 "$STATE_FILE")

prop() {
	systemctl show -p "$1" --value "$UNIT" 2>/dev/null
}

# The vendor unit is the one setup installed
vendor_unchanged() {
	[ -f "$VENDOR" ] || return 1
	[ "$(sha256sum "$VENDOR" | awk '{ print $1 }')" = "$sum" ]
}

# systemd loads the unit from the vendor file, not from a full copy
no_full_override() {
	[ ! -e "/etc/systemd/system/$UNIT" ] || return 1
	[ "$(prop FragmentPath)" = "$VENDOR" ]
}

# A .conf file in the drop-in directory is loaded by systemd
dropin_loaded() {
	local p
	for p in $(prop DropInPaths); do
		case "$p" in
		"$DROPIN_DIR"/*.conf) [ -f "$p" ] && return 0 ;;
		esac
	done
	return 1
}

# The unit environment ends with LAB_MODE=production (last one wins)
unit_env_production() {
	local v last=""
	for v in $(prop Environment); do
		case "$v" in
		LAB_MODE=*) last=$v ;;
		esac
	done
	[ "$last" = LAB_MODE=production ]
}

# The running main process has LAB_MODE=production
process_env_production() {
	local pid
	pid=$(prop MainPID)
	[ -n "$pid" ] && [ "$pid" -gt 0 ] || return 1
	tr '\0' '\n' < "/proc/$pid/environ" | grep -qx LAB_MODE=production
}

# After SIGKILL to the main process the service is active again with a
# new main process within 15 seconds
restarts_after_kill() {
	local old new _
	old=$(prop MainPID)
	[ -n "$old" ] && [ "$old" -gt 0 ] || return 1
	kill -KILL "$old" || return 1
	for _ in $(seq 1 15); do
		sleep 1
		new=$(prop MainPID)
		if [ "$(prop ActiveState)" = active ] && [ -n "$new" ] &&
			[ "$new" -gt 0 ] && [ "$new" != "$old" ]; then
			return 0
		fi
	done
	return 1
}

criterion "Vendor unit $VENDOR is unchanged" vendor_unchanged
criterion "No full copy of $UNIT in /etc/systemd/system" no_full_override
criterion "A drop-in .conf file in $UNIT.d is loaded" dropin_loaded
criterion "$UNIT has Restart=on-failure" test "$(prop Restart)" = on-failure
criterion "$UNIT waits 5 seconds before a restart" test "$(prop RestartUSec)" = 5s
criterion "$UNIT sets LAB_MODE=production" unit_env_production
criterion "The running labapp process has LAB_MODE=production" process_env_production
criterion "$UNIT has a memory limit of 128M (MemoryMax)" test "$(prop MemoryMax)" = 134217728
criterion "$UNIT has a CPU quota of 50%" test "$(prop CPUQuotaPerSecUSec)" = 500ms
criterion "$UNIT is enabled" systemctl is-enabled --quiet "$UNIT"
criterion "$UNIT is active" systemctl is-active --quiet "$UNIT"
# Last: this criterion kills the main process
criterion "$UNIT restarts within 15 seconds after SIGKILL" restarts_after_kill
grade_end
