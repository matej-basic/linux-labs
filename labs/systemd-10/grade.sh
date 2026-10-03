#!/bin/bash
# systemd-10 grader. Reads systemctl show, /proc of the main processes
# and the checksums from the state file; the same properties exist on
# Rocky 8 (systemd 239) and Rocky 9 (systemd 252).
source /opt/linux-labs/lib/grading.sh

LAB=systemd-10
STATE_FILE=/opt/linux-labs/state/$LAB
UNITDIR=/etc/systemd/system
BIN=/usr/local/bin
SVCS="reportd inventoryd metricsd"

grade_begin systemd-10
grade_require_state systemd-10 "$STATE_FILE"

state_value() {
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}

prop() {
	systemctl show -p "$2" --value "$1.service" 2>/dev/null
}

# Enabled, and multi-user.target wants the unit
enabled_multi_user() {
	[ "$(systemctl is-enabled "$1.service" 2>/dev/null)" = enabled ] || return 1
	prop "$1" WantedBy | tr ' ' '\n' | grep -qx multi-user.target
}

# Each program: executable for its user, SELinux type bin_t
programs_executable() {
	local s
	for s in $SVCS; do
		[ -f "$BIN/$s" ] || return 1
		runuser -u "$s" -- test -x "$BIN/$s" || return 1
	done
}
programs_bin_t() {
	local s
	for s in $SVCS; do
		[ "$(stat -c %C "$BIN/$s" 2>/dev/null | cut -d: -f3)" = bin_t ] || return 1
	done
}
programs_unchanged() {
	local s sum
	for s in $SVCS; do
		sum=$(state_value "sum_$s")
		[ -n "$sum" ] || return 1
		[ "$(sha256sum "$BIN/$s" 2>/dev/null | awk '{ print $1 }')" = "$sum" ] || return 1
	done
}

# User= is the service user, and the main process runs the program
# under that user's UID
runs_as_user() {
	local s=$1 pid uid
	[ "$(prop "$s" User)" = "$s" ] || return 1
	pid=$(prop "$s" MainPID)
	[ -n "$pid" ] && [ "$pid" -gt 0 ] || return 1
	uid=$(id -u "$s" 2>/dev/null) || return 1
	[ "$(stat -c %u "/proc/$pid" 2>/dev/null)" = "$uid" ] || return 1
	[ "$(awk '/^Uid:/ { print $2 }' "/proc/$pid/status" 2>/dev/null)" = "$uid" ] || return 1
	tr '\0' '\n' <"/proc/$pid/cmdline" 2>/dev/null | grep -qxF "$BIN/$s"
}

# The unit still reads /etc/sysconfig/inventoryd, the file sets both
# variables, and the running process has the prepared values
inventoryd_settings() {
	local pid env
	[ -f /etc/sysconfig/inventoryd ] || return 1
	prop inventoryd EnvironmentFiles | grep -q '^/etc/sysconfig/inventoryd ' || return 1
	grep -Eq '^[[:space:]]*INVENTORY_DIR=' /etc/sysconfig/inventoryd || return 1
	grep -Eq '^[[:space:]]*SCAN_INTERVAL=' /etc/sysconfig/inventoryd || return 1
	pid=$(prop inventoryd MainPID)
	[ -n "$pid" ] && [ "$pid" -gt 0 ] || return 1
	env=$(tr '\0' '\n' <"/proc/$pid/environ" 2>/dev/null)
	printf '%s\n' "$env" | grep -qx 'INVENTORY_DIR=/var/lib/inventoryd' || return 1
	printf '%s\n' "$env" | grep -qx 'SCAN_INTERVAL=30'
}

# metricsd: Type simple or exec, active, and the same main process is
# still alive a few seconds later
metricsd_stays() {
	local pid
	case $(prop metricsd Type) in
	simple | exec) ;;
	*) return 1 ;;
	esac
	systemctl is-active --quiet metricsd.service || return 1
	pid=$(prop metricsd MainPID)
	[ -n "$pid" ] && [ "$pid" -gt 0 ] || return 1
	sleep 3
	systemctl is-active --quiet metricsd.service || return 1
	[ "$(prop metricsd MainPID)" = "$pid" ] || return 1
	kill -0 "$pid"
}

units_verify() {
	systemd-analyze verify "$UNITDIR/reportd.service" \
		"$UNITDIR/inventoryd.service" "$UNITDIR/metricsd.service"
}

selinux_enforcing() {
	[ "$(getenforce 2>/dev/null)" = Enforcing ] || return 1
	[ "$(sed -n 's/^SELINUX=//p' /etc/selinux/config | head -n 1)" = enforcing ]
}

for s in $SVCS; do
	criterion "$s.service is active" systemctl is-active --quiet "$s.service"
done
for s in $SVCS; do
	criterion "$s.service is enabled for multi-user.target" enabled_multi_user "$s"
done
criterion "The three programs are executable for their users" programs_executable
criterion "The three programs have the SELinux type bin_t" programs_bin_t
criterion "The three programs are unchanged" programs_unchanged
for s in $SVCS; do
	criterion "$s runs $BIN/$s as user $s" runs_as_user "$s"
done
criterion "inventoryd has its settings from /etc/sysconfig/inventoryd" \
	inventoryd_settings
criterion "metricsd.service has a matching Type and keeps running" metricsd_stays
criterion "The three unit files pass systemd-analyze verify" units_verify
criterion "SELinux is enforcing, now and in /etc/selinux/config" selinux_enforcing
grade_end
