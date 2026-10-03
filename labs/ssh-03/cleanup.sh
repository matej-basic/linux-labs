#!/bin/bash
# ssh-03 cleanup: puts /etc/ssh/sshd_config and /etc/ssh/sshd_config.d
# back exactly as they were at the first start, checks them with sshd -t
# and reloads sshd. Then removes the account webdeploy and its home
# directory, /srv/users when the lab created it, the lab key of the task
# user when the lab created it, the known_hosts entries for this machine
# that were added during the lab, and puts the local SELinux
# customizations, permissive domains, policy modules and the SELinux
# mode back as setup.sh recorded them. Last, it restores the package set
# (pkg_restore). When something cannot be restored, the records stay
# for the next reset and the exit status is 1.
#
# sshd is reloaded, not restarted: open sessions, such as the one
# labctl runs this script through, stay open.
source /opt/linux-labs/lib/packages.sh

LAB=ssh-03
ACCOUNT=webdeploy
USERS_DIR=/srv/users
ACCOUNT_HOME=$USERS_DIR/$ACCOUNT
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
REC_DIR="$STATE_DIR/$LAB.d"
SSHD_CONFIG=/etc/ssh/sshd_config
DROPIN_DIR=/etc/ssh/sshd_config.d
KEY_NAME=webdeploy_ed25519

state_value() {
	[ -r "$STATE_FILE" ] || return 0
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}

# The same as in setup.sh
selinux_restore() {
	local rec="$REC_DIR/semanage.export" now line m before
	[ -r "$rec" ] || return 0
	command -v semanage >/dev/null 2>&1 || return 0
	now=$(semanage export 2>/dev/null) || return 0
	printf '%s\n' "$now" | grep -E '^(fcontext|port) -a ' |
		grep -vxF -f "$rec" | sed 's/^\([a-z]*\) -a /\1 -d /' |
		while IFS= read -r line; do
			printf '%s\n' "$line" | semanage import >/dev/null 2>&1 || true
		done
	grep -E '^(fcontext|port) -a ' "$rec" |
		grep -vxF -f <(printf '%s\n' "$now") |
		while IFS= read -r line; do
			printf '%s\n' "$line" | semanage import >/dev/null 2>&1 || true
		done
	if [ "$(printf '%s\n' "$now" | grep '^boolean -m ' | sort)" != \
		"$(grep '^boolean -m ' "$rec" | sort)" ]; then
		semanage boolean -D >/dev/null 2>&1 || true
		grep '^boolean -m ' "$rec" | while IFS= read -r line; do
			printf '%s\n' "$line" | semanage import >/dev/null 2>&1 || true
		done
	fi
	getsebool -a 2>/dev/null | grep -vxF -f "$REC_DIR/booleans" |
		awk '{ print $1 }' | while read -r m; do
			line=$(awk -v b="$m" '$1 == b { print $3 }' "$REC_DIR/booleans")
			[ -n "$line" ] && setsebool "$m" "$line" >/dev/null 2>&1
			true
		done
	semanage permissive -l 2>/dev/null | awk 'NF == 1 { print $1 }' | sort -u |
		grep -vxF -f "$REC_DIR/permissive" | while read -r m; do
			semanage permissive -d "$m" >/dev/null 2>&1 || true
		done
	before=$(state_value modules)
	for m in $(semodule -lfull 2>/dev/null | awk '$1 == 400 { print $2 }'); do
		case " $before " in
		*" $m "*) ;;
		*) semodule -X 400 -r "$m" >/dev/null 2>&1 || true ;;
		esac
	done
}

rc=0

# Without the state file the lab did not start: leave sshd and the
# accounts alone, only restore packages if a snapshot exists
if [ -r "$STATE_FILE" ]; then
	owner=$(state_value owner)
	home=$(state_value home)

	# 1. SSH server configuration, byte for byte
	if [ -f "$REC_DIR/sshd_config" ]; then
		cp -a "$REC_DIR/sshd_config" "$SSHD_CONFIG"
		rm -rf "$DROPIN_DIR"
		if [ "$(state_value dropin_dir)" = 1 ] && [ -d "$REC_DIR/sshd_config.d" ]; then
			cp -a "$REC_DIR/sshd_config.d" "$DROPIN_DIR"
		fi
		restorecon -R /etc/ssh >/dev/null 2>&1
		if sshd -t >/dev/null 2>&1; then
			systemctl reload-or-restart sshd >/dev/null 2>&1 || {
				echo "Error: sshd did not reload after the configuration was restored." >&2
				rc=1
			}
		else
			echo "Error: the restored SSH server configuration fails sshd -t; sshd was not reloaded." >&2
			rc=1
		fi
	fi

	# 2. The account and its home directory
	if getent passwd "$ACCOUNT" >/dev/null; then
		pkill -KILL -u "$ACCOUNT" >/dev/null 2>&1
		sleep 1
		userdel -r -f "$ACCOUNT" >/dev/null 2>&1
	fi
	groupdel "$ACCOUNT" >/dev/null 2>&1
	rm -rf "$ACCOUNT_HOME"
	if [ "$(state_value users_dir_existed)" = 0 ]; then
		rm -rf "$USERS_DIR"
	fi

	# 3. The lab key and the known_hosts entries of the task user
	if [ -n "$home" ] && [ -n "$owner" ] && [ -d "$home/.ssh" ]; then
		if [ "$(state_value key_existed)" = 0 ]; then
			rm -f "$home/.ssh/$KEY_NAME" "$home/.ssh/$KEY_NAME.pub"
		fi
		kh="$home/.ssh/known_hosts"
		if [ "$(state_value kh_existed)" = 0 ]; then
			rm -f "$kh"
		elif [ -f "$kh" ]; then
			kh_had=" $(state_value kh_had) "
			# The names setup.sh looked for; hostname -I is a word list
			names="localhost 127.0.0.1 ::1 $(hostname -s) $(hostname)"
			names="$names $(hostname -I 2>/dev/null)"
			for n in $names; do
				case "$kh_had" in
				*" $n "*) ;;
				*) runuser -u "$owner" -- ssh-keygen -R "$n" -f "$kh" >/dev/null 2>&1 ;;
				esac
			done
		fi
		if [ "$(state_value kh_old_existed)" = 0 ]; then
			rm -f "$home/.ssh/known_hosts.old"
		fi
	fi

	# 4. SELinux, before pkg_restore can remove semanage
	if command -v getenforce >/dev/null 2>&1 && [ "$(getenforce 2>/dev/null)" != Disabled ]; then
		selinux_restore
		setenforce 1 >/dev/null 2>&1
		cfg=$(state_value selinux_cfg)
		if [ -n "$cfg" ]; then
			sed -i "s/^SELINUX=.*/SELINUX=$cfg/" /etc/selinux/config
		fi
	fi
fi

pkg_restore "$LAB" || rc=1

if [ "$rc" -eq 0 ]; then
	rm -rf "$REC_DIR"
	rm -f "$STATE_FILE" "$STATE_FILE.tmp"
fi
exit "$rc"
