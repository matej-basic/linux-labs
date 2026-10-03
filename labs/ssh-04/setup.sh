#!/bin/bash
# ssh-04 setup: a lab key pair for the SFTP accounts. The public half is
# ~/sftp-lab.pub of the task user, the private half stays readable by
# root only in /opt/linux-labs/state/ssh-04.d/sftp-lab, where the grader
# uses it for a real SFTP session. The student creates the group, the
# accounts, the chroot directories and the Match block.
# Prints nothing on success.
#
# The first run records the package set (pkg_snapshot), a copy of
# /etc/ssh/sshd_config and /etc/ssh/sshd_config.d, the effective sshd
# configuration of the task user, the SELinux booleans, the local file
# context rules, the SELinux mode in /etc/selinux/config and the
# known_hosts entries for this machine of the task user and of root.
#
# Safety: setup does not change the SSH server configuration. On a
# second run it only puts back the copy from the first run, checks it
# with sshd -t and reloads sshd, so key logins as the task user on
# port 22 keep working.
set -eu
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

if ! command -v getenforce >/dev/null 2>&1 || [ "$(getenforce)" = Disabled ]; then
	echo "Error: SELinux is disabled; this lab needs SELinux enabled." >&2
	exit 1
fi
if ! systemctl is-active --quiet sshd; then
	echo "Error: sshd is not running on this machine." >&2
	exit 1
fi

state_value() {
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}

# Task user: LAB_USER from labctl, else the first regular user
owner="${LAB_USER:-student}"
if ! id "$owner" &>/dev/null; then
	owner=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 { print $1; exit }')
fi
if [ -z "$owner" ] || ! id "$owner" &>/dev/null; then
	echo "Error: no regular user account found for the lab." >&2
	exit 1
fi
home=$(getent passwd "$owner" | cut -d: -f6)
if [ -z "$home" ] || [ ! -d "$home" ]; then
	echo "Error: the home directory of $owner does not exist." >&2
	exit 1
fi
root_home=$(getent passwd root | cut -d: -f6)

# The names a client may use for this machine in known_hosts
kh_names() {
	local a
	printf '%s\n' localhost 127.0.0.1 ::1 "$(hostname -s)" "$(hostname)"
	for a in $(hostname -I 2>/dev/null); do
		printf '%s\n' "$a"
	done
}

# kh_record <home>: which of those names known_hosts in <home> has
kh_record() {
	local kh="$1/.ssh/known_hosts" n had=
	if [ -f "$kh" ]; then
		for n in $(kh_names); do
			ssh-keygen -F "$n" -f "$kh" >/dev/null 2>&1 && had="$had $n"
		done
	fi
	printf '%s' "$had"
}

# First run only: refuse to take over what the lab did not create
if [ ! -r "$STATE_FILE" ]; then
	for a in $GROUP $ACCOUNTS; do
		if getent passwd "$a" >/dev/null || getent group "$a" >/dev/null; then
			echo "Error: user or group $a already exists and was not created by this lab." >&2
			exit 1
		fi
	done
	for p in "$SFTP_ROOT" /home/ftpa /home/ftpb "$home/$PUB_NAME"; do
		if [ -e "$p" ]; then
			echo "Error: $p already exists and was not created by this lab." >&2
			exit 1
		fi
	done
	if ! sshd -t >/dev/null 2>&1; then
		echo "Error: the SSH server configuration does not pass sshd -t." >&2
		exit 1
	fi
fi

pkg_snapshot "$LAB"

# First run only: what the machine looked like before the lab
if [ ! -r "$STATE_FILE" ]; then
	rm -rf "$REC_DIR"
	mkdir -p "$STATE_DIR"
	mkdir -m 0700 "$REC_DIR"
	cp -a "$SSHD_CONFIG" "$REC_DIR/sshd_config"
	dropin_dir=0
	if [ -d "$DROPIN_DIR" ]; then
		dropin_dir=1
		cp -a "$DROPIN_DIR" "$REC_DIR/sshd_config.d"
	fi
	sshd -T -C "user=$owner,host=localhost,addr=127.0.0.1" > "$REC_DIR/owner.sshd" 2>/dev/null
	if [ ! -s "$REC_DIR/owner.sshd" ]; then
		echo "Error: sshd -T did not print the configuration of $owner." >&2
		rm -rf "$REC_DIR"
		exit 1
	fi
	getsebool -a > "$REC_DIR/booleans"
	# Local file context rules (none recorded when semanage is missing)
	: > "$REC_DIR/fcontext"
	if command -v semanage >/dev/null 2>&1; then
		semanage export 2>/dev/null | grep '^fcontext -a ' > "$REC_DIR/fcontext" || true
	fi
	selinux_cfg=$(sed -n 's/^SELINUX=//p' /etc/selinux/config | head -n 1)
	ssh-keygen -q -t ed25519 -N '' -C "$LAB" -f "$REC_DIR/sftp-lab"
	chmod 0600 "$REC_DIR/sftp-lab"

	kh_owner_existed=0
	[ -e "$home/.ssh/known_hosts" ] && kh_owner_existed=1
	kh_owner_old=0
	[ -e "$home/.ssh/known_hosts.old" ] && kh_owner_old=1
	kh_root_existed=0
	[ -e "$root_home/.ssh/known_hosts" ] && kh_root_existed=1
	kh_root_old=0
	[ -e "$root_home/.ssh/known_hosts.old" ] && kh_root_old=1
	root_ssh_existed=0
	[ -e "$root_home/.ssh" ] && root_ssh_existed=1

	tmp="$STATE_FILE.tmp"
	{
		echo "owner=$owner"
		echo "home=$home"
		echo "dropin_dir=$dropin_dir"
		echo "selinux_cfg=$selinux_cfg"
		echo "kh_owner_existed=$kh_owner_existed"
		echo "kh_owner_had=$(kh_record "$home")"
		echo "kh_owner_old=$kh_owner_old"
		echo "kh_root_existed=$kh_root_existed"
		echo "kh_root_had=$(kh_record "$root_home")"
		echo "kh_root_old=$kh_root_old"
		echo "root_ssh_existed=$root_ssh_existed"
	} > "$tmp"
	chmod 0644 "$tmp"
	mv "$tmp" "$STATE_FILE"
fi

# sshd_restore: the recorded sshd_config and sshd_config.d, checked
# with sshd -t and reloaded when anything changed
sshd_restore() {
	local changed=0
	if ! cmp -s "$REC_DIR/sshd_config" "$SSHD_CONFIG"; then
		cp -a "$REC_DIR/sshd_config" "$SSHD_CONFIG"
		changed=1
	fi
	if [ "$(state_value dropin_dir)" = 1 ]; then
		if ! diff -r "$REC_DIR/sshd_config.d" "$DROPIN_DIR" >/dev/null 2>&1; then
			rm -rf "$DROPIN_DIR"
			cp -a "$REC_DIR/sshd_config.d" "$DROPIN_DIR"
			changed=1
		fi
	elif [ -e "$DROPIN_DIR" ]; then
		rm -rf "$DROPIN_DIR"
		changed=1
	fi
	[ "$changed" = 1 ] || return 0
	restorecon -R /etc/ssh >/dev/null 2>&1 || true
	if ! sshd -t >/dev/null 2>&1; then
		echo "Error: the recorded SSH server configuration fails sshd -t." >&2
		return 1
	fi
	systemctl reload sshd
}

# selinux_restore: booleans that changed since the first start get their
# recorded value back, file context rules for /srv/sftp added since
# then go
selinux_restore() {
	local b v line
	getsebool -a 2>/dev/null | grep -vxF -f "$REC_DIR/booleans" |
		awk '{ print $1 }' | while read -r b; do
			v=$(awk -v b="$b" '$1 == b { print $3 }' "$REC_DIR/booleans")
			[ -n "$v" ] && setsebool -P "$b" "$v" >/dev/null 2>&1
			true
		done
	command -v semanage >/dev/null 2>&1 || return 0
	semanage export 2>/dev/null | grep '^fcontext -a ' |
		grep -F "$SFTP_ROOT" | grep -vxF -f "$REC_DIR/fcontext" | sed 's/^fcontext -a /fcontext -d /' |
		while IFS= read -r line; do
			printf '%s\n' "$line" | semanage import >/dev/null 2>&1 || true
		done
}

owner=$(state_value owner)
home=$(state_value home)
group=$(id -gn "$owner")

# Reset what a previous run or the solution left behind
sshd_restore
for a in $ACCOUNTS; do
	if getent passwd "$a" >/dev/null; then
		pkill -KILL -u "$a" >/dev/null 2>&1 || true
		userdel -r -f "$a" >/dev/null 2>&1 || true
	fi
	groupdel "$a" >/dev/null 2>&1 || true
	rm -rf "/home/${a:?}" "/var/spool/mail/${a:?}"
done
groupdel "$GROUP" >/dev/null 2>&1 || true
rm -rf "$SFTP_ROOT"
selinux_restore
setenforce 1
sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config

# The public half of the lab key for the task user
ssh-keygen -y -f "$REC_DIR/sftp-lab" > "$REC_DIR/sftp-lab.pub"
install -m 0644 -o "$owner" -g "$group" "$REC_DIR/sftp-lab.pub" "$home/$PUB_NAME"
restorecon "$home/$PUB_NAME" >/dev/null 2>&1 || true
exit 0
