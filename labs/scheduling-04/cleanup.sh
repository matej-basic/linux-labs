#!/bin/bash
# scheduling-04 cleanup: remove the at jobs created since the first
# start, the lab users, the report file and the state, and restore
# /etc/at.allow, /etc/at.deny, the task user's ~/.bashrc and
# ~/.bash_profile and the state of atd as setup.sh recorded them. at goes
# again if the lab installed it (pkg_restore). Safe when the lab was
# never started.
source /opt/linux-labs/lib/packages.sh

LAB=scheduling-04
STATE_DIR=/opt/linux-labs/state/$LAB
LAB_USERS="reporter intern"
rc=0

restore() {
	if [ -f "$STATE_DIR/$2" ]; then
		if [ -f "$1" ]; then
			cat "$STATE_DIR/$2" > "$1"
			touch -r "$STATE_DIR/$2" "$1"
		else
			cp -p "$STATE_DIR/$2" "$1"
			restorecon "$1" >/dev/null 2>&1 || true
		fi
	elif [ -f "$STATE_DIR/$2.absent" ]; then
		rm -f "$1"
	fi
}

restore_at_files() {
	restore /etc/at.allow at.allow
	restore /etc/at.deny at.deny
}

owner=$(head -n 1 "$STATE_DIR/owner" 2>/dev/null)
home=
[ -n "$owner" ] && home=$(getent passwd "$owner" | cut -d: -f6)

# at jobs that did not exist at the first start (any user)
if [ -f "$STATE_DIR/jobs" ] && command -v atq >/dev/null 2>&1; then
	for id in $(atq 2>/dev/null | awk '{ print $1 }' | sort |
		comm -23 - "$STATE_DIR/jobs"); do
		atrm "$id" 2>/dev/null || true
	done
fi

for u in $LAB_USERS; do
	if id "$u" &>/dev/null; then
		pkill -KILL -u "$u" 2>/dev/null || true
		userdel -r "$u" >/dev/null 2>&1 || true
	fi
done

if [ -n "$home" ] && [ -d "$home" ]; then
	restore "$home/.bashrc" bashrc
	restore "$home/.bash_profile" bash_profile
	rm -f "$home/disk-report.txt"
fi

# Before pkg_restore, so that a removed at leaves no changed at.deny
restore_at_files

at_before=no
pkg_was_installed "$LAB" at && at_before=yes

pkg_restore "$LAB" || rc=1

# at came with the lab: rpm leaves the spool directory with the job
# sequence file behind on Rocky 9
if [ "$at_before" = no ] && ! rpm -q at >/dev/null 2>&1; then
	rm -rf /var/spool/at
fi

# at was there before the lab: its files and atd as they were
if [ "$at_before" = yes ] && rpm -q at >/dev/null 2>&1; then
	restore_at_files
	read -r en ac < "$STATE_DIR/atd" 2>/dev/null || { en=; ac=; }
	if [ "$en" = enabled ]; then
		systemctl enable atd.service >/dev/null 2>&1 || rc=1
	elif [ -n "$en" ]; then
		systemctl disable atd.service >/dev/null 2>&1 || rc=1
	fi
	if [ "$ac" = active ]; then
		systemctl start atd.service >/dev/null 2>&1 || rc=1
	elif [ -n "$ac" ]; then
		systemctl stop atd.service >/dev/null 2>&1 || rc=1
	fi
fi

if [ "$rc" -eq 0 ]; then
	rm -rf "$STATE_DIR"
fi
exit "$rc"
