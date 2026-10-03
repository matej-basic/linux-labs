#!/bin/bash
# ssh-05 cleanup: puts /etc/ssh/sshd_config and /etc/ssh/sshd_config.d
# back exactly as they were at the first start, checks them with sshd -t
# and reloads sshd. Then removes the files in /etc/ssh that were not
# there at the first start (the CA, a principals file), the account
# deploy with its home, the lab key and the certificate, the known_hosts
# entries for this machine that root or the task user added during the
# lab, and puts the SELinux mode back. Last, it restores the package set
# (pkg_restore). When something cannot be restored, the records stay
# for the next reset and the exit status is 1.
#
# sshd is reloaded, not restarted: open sessions, such as the one
# labctl runs this script through, stay open.
source /opt/linux-labs/lib/packages.sh

LAB=ssh-05
ACCOUNT=deploy
KEY_NAME=deploy_ed25519
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
REC_DIR="$STATE_DIR/$LAB.d"
SSHD_CONFIG=/etc/ssh/sshd_config
DROPIN_DIR=/etc/ssh/sshd_config.d

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

	# 2. New files in /etc/ssh (the CA), host keys excepted, only once
	# the configuration no longer points to them
	if [ "$rc" -eq 0 ] && [ -r "$REC_DIR/etc-ssh" ]; then
		for p in /etc/ssh/*; do
			[ -e "$p" ] || continue
			n=${p##*/}
			case "$n" in
			ssh_host_*) continue ;;
			esac
			grep -qxF "$n" "$REC_DIR/etc-ssh" || rm -rf "/etc/ssh/${n:?}"
		done
	fi

	# 3. The account deploy and its home
	pkill -KILL -u "$ACCOUNT" >/dev/null 2>&1 && sleep 1
	if getent passwd "$ACCOUNT" >/dev/null; then
		userdel -r -f "$ACCOUNT" >/dev/null 2>&1
	fi
	groupdel "$ACCOUNT" >/dev/null 2>&1
	rm -rf "/home/${ACCOUNT:?}" "/var/spool/mail/${ACCOUNT:?}"

	# 4. The lab key, the certificate and the known_hosts entries
	if [ -n "$home" ]; then
		rm -f "$home/$KEY_NAME.pub" "$home/$KEY_NAME-cert.pub"
	fi
	if [ -n "$home" ] && [ -n "$owner" ]; then
		kh_clean "$home" "$owner" "$(state_value kh_owner_existed)" \
			"$(state_value kh_owner_had)" "$(state_value kh_owner_old)"
	fi
	kh_clean "$root_home" root "$(state_value kh_root_existed)" \
		"$(state_value kh_root_had)" "$(state_value kh_root_old)"
	if [ "$(state_value root_ssh_existed)" = 0 ]; then
		rmdir "$root_home/.ssh" >/dev/null 2>&1
	fi

	# 5. SELinux mode
	if command -v getenforce >/dev/null 2>&1 && [ "$(getenforce 2>/dev/null)" != Disabled ]; then
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
