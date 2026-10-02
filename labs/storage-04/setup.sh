#!/bin/bash
# storage-04 setup: start without the lab's swap file, fstab entry and
# sysctl file. Prints nothing on success.
#
# The first run records the package set (pkg_snapshot), the swap areas
# that are active, vm.swappiness, and whether tuned was installed,
# enabled and running with which profile. A later start keeps those
# records and puts the recorded tuned and swappiness state back, so a
# second start after a partial solution gives the same starting point.
# cleanup.sh restores the same records.
set -eu
source /opt/linux-labs/lib/packages.sh

STATE_FILE=/opt/linux-labs/state/storage-04
SWAPFILE=/swapfile
SYSCTL_FILE=/etc/sysctl.d/90-swappiness.conf

state_value() {
	[ -r "$STATE_FILE" ] || return 0
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}

# Remove the swap file and its fstab entry
remove_swapfile() {
	if swapon --show=NAME --noheadings --raw 2>/dev/null | grep -qxF "$SWAPFILE"; then
		swapoff "$SWAPFILE"
	fi
	rm -f "$SWAPFILE"
	if awk -v f="$SWAPFILE" '!/^[[:space:]]*#/ && $1 == f { found = 1 }
		END { exit !found }' /etc/fstab; then
		awk -v f="$SWAPFILE" '/^[[:space:]]*#/ { print; next }
			$1 == f { next } { print }' /etc/fstab > /etc/fstab.storage-04.new
		cat /etc/fstab.storage-04.new > /etc/fstab
		rm -f /etc/fstab.storage-04.new
		systemctl daemon-reload 2>/dev/null || true
	fi
}

# Put tuned back to the recorded state (installed, profile, mode,
# enabled, running). A tuned the lab installed is stopped and disabled;
# reset removes the package.
restore_tuned() {
	rpm -q tuned >/dev/null 2>&1 || return 0
	if [ "$(state_value tuned_installed)" != yes ]; then
		systemctl disable --now tuned >/dev/null 2>&1 || true
		return 0
	fi
	systemctl stop tuned >/dev/null 2>&1 || true
	mkdir -p /etc/tuned
	state_value tuned_profile > /etc/tuned/active_profile
	if [ -n "$(state_value tuned_mode)" ]; then
		state_value tuned_mode > /etc/tuned/profile_mode
	fi
	if [ "$(state_value tuned_enabled)" = yes ]; then
		systemctl enable tuned >/dev/null 2>&1 || true
	else
		systemctl disable tuned >/dev/null 2>&1 || true
	fi
	if [ "$(state_value tuned_active)" = yes ]; then
		systemctl start tuned >/dev/null 2>&1 || true
	fi
}

pkg_snapshot storage-04

remove_swapfile

if [ ! -r "$STATE_FILE" ]; then
	# A sysctl file left over without records: drop it and reload the
	# remaining settings, so that the recorded value is the system's own
	if [ -e "$SYSCTL_FILE" ]; then
		rm -f "$SYSCTL_FILE"
		sysctl -q --system >/dev/null 2>&1 || true
		if systemctl is-active --quiet tuned 2>/dev/null; then
			systemctl restart tuned >/dev/null 2>&1 || true
		fi
	fi
	installed=no
	enabled=no
	active=no
	profile=
	mode=
	if rpm -q tuned >/dev/null 2>&1; then
		installed=yes
		systemctl is-enabled --quiet tuned 2>/dev/null && enabled=yes
		systemctl is-active --quiet tuned 2>/dev/null && active=yes
		profile=$(head -n 1 /etc/tuned/active_profile 2>/dev/null || true)
		mode=$(head -n 1 /etc/tuned/profile_mode 2>/dev/null || true)
	fi
	swaps=$(swapon --show=NAME --noheadings --raw 2>/dev/null | tr '\n' ' ' || true)
	mkdir -p "$(dirname "$STATE_FILE")"
	{
		echo "swappiness=$(sysctl -n vm.swappiness)"
		echo "swaps=${swaps% }"
		echo "tuned_installed=$installed"
		echo "tuned_enabled=$enabled"
		echo "tuned_active=$active"
		echo "tuned_profile=$profile"
		echo "tuned_mode=$mode"
	} > "$STATE_FILE"
	chmod 644 "$STATE_FILE"
else
	rm -f "$SYSCTL_FILE"
	restore_tuned
	sysctl -q -w "vm.swappiness=$(state_value swappiness)" >/dev/null
fi

# The swap file needs room on the root filesystem: 512 MiB plus a margin
avail=$(df -P -k / | awk 'NR == 2 { print $4 }')
if [ "${avail:-0}" -lt $((1024 * 1024)) ]; then
	echo "storage-04: less than 1 GiB free on /; refusing to start" >&2
	exit 1
fi
