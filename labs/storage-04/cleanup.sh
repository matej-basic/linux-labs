#!/bin/bash
# storage-04 cleanup: deactivate and remove the swap file and its fstab
# entry, remove the sysctl file, put tuned back to the profile and
# service state recorded at the first start, set vm.swappiness to the
# recorded value and restore the package set (pkg_restore removes tuned
# if the lab installed it). Safe to run repeatedly. When the package set
# cannot be restored, the records stay for the next reset and the exit
# status is 1.
source /opt/linux-labs/lib/packages.sh

STATE_FILE=/opt/linux-labs/state/storage-04
SWAPFILE=/swapfile
SYSCTL_FILE=/etc/sysctl.d/90-swappiness.conf

state_value() {
	[ -r "$STATE_FILE" ] || return 0
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}

# Drop the fstab entry first, so nothing activates the file again
if awk -v f="$SWAPFILE" '!/^[[:space:]]*#/ && $1 == f { found = 1 }
	END { exit !found }' /etc/fstab 2>/dev/null; then
	awk -v f="$SWAPFILE" '/^[[:space:]]*#/ { print; next }
		$1 == f { next } { print }' /etc/fstab > /etc/fstab.storage-04.new &&
		cat /etc/fstab.storage-04.new > /etc/fstab
	rm -f /etc/fstab.storage-04.new
	systemctl daemon-reload 2>/dev/null || true
fi
if swapon --show=NAME --noheadings --raw 2>/dev/null | grep -qxF "$SWAPFILE"; then
	swapoff "$SWAPFILE" 2>/dev/null || true
fi
rm -f "$SWAPFILE"
systemctl reset-failed swapfile.swap >/dev/null 2>&1 || true
rm -f "$SYSCTL_FILE"

if [ -r "$STATE_FILE" ] && rpm -q tuned >/dev/null 2>&1; then
	if [ "$(state_value tuned_installed)" = yes ]; then
		# Stopping tuned rolls back its tuning; the start applies the
		# recorded profile
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
	else
		systemctl disable --now tuned >/dev/null 2>&1 || true
	fi
fi

swappiness=$(state_value swappiness)
if [ -n "$swappiness" ]; then
	sysctl -q -w "vm.swappiness=$swappiness" >/dev/null 2>&1 || true
fi

# On Rocky 9, tuned pulls in polkit. Removing polkit again leaves an
# empty /etc/polkit-1/rules.d owned by the new system user polkitd, so
# pkg_restore keeps that user and fails. When the lab brought polkit in,
# remove the leftover directory and let pkg_restore finish.
polkit_new=no
pkg_was_installed storage-04 polkit 2>/dev/null || polkit_new=yes

rc=0
if ! pkg_restore storage-04 2>/dev/null; then
	if [ "$polkit_new" = yes ] && ! rpm -q polkit >/dev/null 2>&1 \
		&& [ -d /etc/polkit-1 ] && ! rpm -qf /etc/polkit-1 >/dev/null 2>&1; then
		rm -rf /etc/polkit-1
	fi
	pkg_restore storage-04 || rc=1
fi

# tuned is gone again: its runtime configuration too
if [ "$(state_value tuned_installed)" = no ] && ! rpm -q tuned >/dev/null 2>&1 \
	&& [ -d /etc/tuned ] && ! rpm -qf /etc/tuned >/dev/null 2>&1; then
	rm -rf /etc/tuned
fi

if [ "$rc" -eq 0 ]; then
	rm -f "$STATE_FILE"
fi
exit "$rc"
