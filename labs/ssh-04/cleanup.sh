#!/bin/bash
# ssh-04 cleanup: puts /etc/ssh/sshd_config and /etc/ssh/sshd_config.d
# back exactly as they were at the first start, checks them with sshd -t
# and reloads sshd. Then removes the accounts ftpa and ftpb with their
# homes, the group sftponly, /srv/sftp, the lab key, the known_hosts
# entries for this machine that root or the task user added during the
# lab, the file context rules for /srv/sftp, and puts the SELinux
# booleans and mode back. Last, it restores the package set
# (pkg_restore). When something cannot be restored, the records stay
# for the next reset and the exit status is 1.
#
# sshd is reloaded, not restarted: open sessions, such as the one
# labctl runs this script through, stay open.
source /opt/linux-labs/lib/packages.sh

LAB=ssh-04
GROUP=sftponly
ACCOUNTS="ftpa ftpb"
SFTP_ROOT=/srv/sftp
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
REC_DIR="$STATE_DIR/$LAB.d"
SSHD_CONFIG=/etc/ssh/sshd_config
DROPIN_DIR=/etc/ssh/sshd_config.d
PUB_NAME=sftp-lab.pub

state_value() {
	[ -r "$STATE_FILE" ] || return 0
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}

# kh_clean <home> <user> <existed> <had> <old>: remove the names of
# this machine that were not in known_hosts at the first start, and the
# backup file ssh-keygen -R writes when there was none
kh_clean() {
	local home="$1" user="$2" existed="$3" had=" $4 " old="$5" kh n names
	kh="$home/.ssh/known_hosts"
	[ -d "$home/.ssh" ] || return 0
	if [ "$existed" = 0 ]; then
		rm -f "$kh"
	elif [ -f "$kh" ]; then
		names="localhost 127.0.0.1 ::1 $(hostname -s) $(hostname)"
		names="$names $(hostname -I 2>/dev/null)"
		for n in $names; do
			case "$had" in
			*" $n "*) ;;
			*) runuser -u "$user" -- ssh-keygen -R "$n" -f "$kh" >/dev/null 2>&1 ;;
			esac
		done
	fi
	[ "$old" = 1 ] || rm -f "$kh.old"
}

rc=0

# Without the state file the lab did not start: leave sshd and the
# accounts alone, only restore packages if a snapshot exists
if [ -r "$STATE_FILE" ]; then
	owner=$(state_value owner)
	home=$(state_value home)
	root_home=$(getent passwd root | cut -d: -f6)

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

	# 2. The accounts, their homes, the group and the chroot tree
	for a in $ACCOUNTS; do
		pkill -KILL -u "$a" >/dev/null 2>&1
	done
	sleep 1
	for a in $ACCOUNTS; do
		if getent passwd "$a" >/dev/null; then
			userdel -r -f "$a" >/dev/null 2>&1
		fi
		groupdel "$a" >/dev/null 2>&1
		rm -rf "/home/${a:?}" "/var/spool/mail/${a:?}"
	done
	groupdel "$GROUP" >/dev/null 2>&1
	rm -rf "$SFTP_ROOT"

	# 3. The lab key and the known_hosts entries
	[ -n "$home" ] && rm -f "$home/$PUB_NAME"
	if [ -n "$home" ] && [ -n "$owner" ]; then
		kh_clean "$home" "$owner" "$(state_value kh_owner_existed)" \
			"$(state_value kh_owner_had)" "$(state_value kh_owner_old)"
	fi
	kh_clean "$root_home" root "$(state_value kh_root_existed)" \
		"$(state_value kh_root_had)" "$(state_value kh_root_old)"
	if [ "$(state_value root_ssh_existed)" = 0 ]; then
		rmdir "$root_home/.ssh" >/dev/null 2>&1
	fi

	# 4. SELinux, before pkg_restore can remove semanage
	if command -v getenforce >/dev/null 2>&1 && [ "$(getenforce 2>/dev/null)" != Disabled ]; then
		if [ -r "$REC_DIR/booleans" ]; then
			getsebool -a 2>/dev/null | grep -vxF -f "$REC_DIR/booleans" |
				awk '{ print $1 }' | while read -r b; do
					v=$(awk -v b="$b" '$1 == b { print $3 }' "$REC_DIR/booleans")
					[ -n "$v" ] && setsebool -P "$b" "$v" >/dev/null 2>&1
					true
				done
		fi
		if [ -r "$REC_DIR/fcontext" ] && command -v semanage >/dev/null 2>&1; then
			semanage export 2>/dev/null | grep '^fcontext -a ' |
				grep -F "$SFTP_ROOT" | grep -vxF -f "$REC_DIR/fcontext" |
				sed 's/^fcontext -a /fcontext -d /' |
				while IFS= read -r line; do
					printf '%s\n' "$line" | semanage import >/dev/null 2>&1
				done
		fi
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
