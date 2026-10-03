#!/bin/bash
# ssh-03 setup: the system account webdeploy with the home directory
# /srv/users/webdeploy, and a key pair for the task user whose public
# key is in the authorized keys file of webdeploy. A key login as
# webdeploy fails, for four reasons at the same time:
#   - the home directory has mode 0777 (StrictModes refuses the keys)
#   - the home directory is under /srv and has the type var_t, and no
#     file context rule gives it a home type (SELinux denies sshd the
#     authorized keys file)
#   - a Match User webdeploy block at the end of /etc/ssh/sshd_config
#     turns public key authentication off for webdeploy
#   - the login shell of webdeploy is /sbin/nologin
# webdeploy is a system account (UID below 1000) on purpose: for a
# regular account with a valid shell, the SELinux tools would add
# /srv/users as a home root by themselves.
# Prints nothing on success.
#
# The first run records the package set (pkg_snapshot), a copy of
# /etc/ssh/sshd_config and /etc/ssh/sshd_config.d, the local SELinux
# customizations (semanage export), the booleans, the policy modules,
# the permissive domains, the SELinux mode in /etc/selinux/config, the
# effective sshd configuration of the task user and the known_hosts
# entries of the task user for this machine.
#
# Safety: setup never changes Port, AllowUsers, DenyUsers,
# PubkeyAuthentication or anything else for the task user, who is how
# labctl reaches this machine. The planted Match block applies to
# webdeploy only, and sshd is reloaded only after sshd -t passes.
set -eu
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

# The names a student may use for this machine in known_hosts
kh_names() {
	local a
	printf '%s\n' localhost 127.0.0.1 ::1 "$(hostname -s)" "$(hostname)"
	for a in $(hostname -I 2>/dev/null); do
		printf '%s\n' "$a"
	done
}

# First run only: refuse to take over what the lab did not create
if [ ! -r "$STATE_FILE" ]; then
	if getent passwd "$ACCOUNT" >/dev/null || getent group "$ACCOUNT" >/dev/null; then
		echo "Error: user or group $ACCOUNT already exists and was not created by this lab." >&2
		exit 1
	fi
	if [ -e "$ACCOUNT_HOME" ]; then
		echo "Error: $ACCOUNT_HOME already exists and was not created by this lab." >&2
		exit 1
	fi
	if ! sshd -t >/dev/null 2>&1; then
		echo "Error: the SSH server configuration does not pass sshd -t." >&2
		exit 1
	fi
fi

pkg_snapshot "$LAB"

if ! rpm -q policycoreutils-python-utils >/dev/null 2>&1; then
	# dnf reports a repo key import on stderr; show its output only
	# when the install fails
	if ! out=$(dnf -y -q install policycoreutils-python-utils </dev/null 2>&1); then
		printf '%s\n' "$out" >&2
		echo "Error: could not install policycoreutils-python-utils." >&2
		exit 1
	fi
fi

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
	semanage export > "$REC_DIR/semanage.export"
	getsebool -a > "$REC_DIR/booleans"
	semanage permissive -l 2>/dev/null | awk 'NF == 1 { print $1 }' |
		sort -u > "$REC_DIR/permissive"
	modules=$(semodule -l | awk '{ print $1 }' | sort | tr '\n' ' ')
	selinux_cfg=$(sed -n 's/^SELINUX=//p' /etc/selinux/config | head -n 1)
	sshd -T -C "user=$owner,host=localhost,addr=127.0.0.1" > "$REC_DIR/owner.sshd" 2>/dev/null
	[ -s "$REC_DIR/owner.sshd" ] || {
		echo "Error: sshd -T did not print the configuration of $owner." >&2
		rm -rf "$REC_DIR"
		exit 1
	}

	# The lab key: an existing passphrase-less key of that name is
	# used as it is, otherwise the lab creates one
	key="$home/.ssh/$KEY_NAME"
	key_existed=0
	if [ -e "$key" ]; then
		key_existed=1
		if ! ssh-keygen -y -P '' -f "$key" > "$REC_DIR/key.pub" 2>/dev/null; then
			echo "Error: $key exists and cannot be used without a passphrase." >&2
			rm -rf "$REC_DIR"
			exit 1
		fi
		cp "$key" "$REC_DIR/key"
	else
		ssh-keygen -q -t ed25519 -N '' -C "$LAB" -f "$REC_DIR/key"
	fi
	chmod 0600 "$REC_DIR/key"

	# known_hosts of the task user: which names of this machine it
	# already has
	kh="$home/.ssh/known_hosts"
	kh_existed=0
	kh_old_existed=0
	kh_had=
	[ -e "$home/.ssh/known_hosts.old" ] && kh_old_existed=1
	if [ -f "$kh" ]; then
		kh_existed=1
		for n in $(kh_names); do
			ssh-keygen -F "$n" -f "$kh" >/dev/null 2>&1 && kh_had="$kh_had $n"
		done
	fi
	users_dir_existed=0
	[ -e "$USERS_DIR" ] && users_dir_existed=1

	tmp="$STATE_FILE.tmp"
	{
		echo "owner=$owner"
		echo "home=$home"
		echo "dropin_dir=$dropin_dir"
		echo "modules=$modules"
		echo "selinux_cfg=$selinux_cfg"
		echo "key_existed=$key_existed"
		echo "kh_existed=$kh_existed"
		echo "kh_old_existed=$kh_old_existed"
		echo "kh_had=$kh_had"
		echo "users_dir_existed=$users_dir_existed"
	} > "$tmp"
	chmod 0644 "$tmp"
	mv "$tmp" "$STATE_FILE"
fi

# Put the local SELinux customizations (file context and port rules,
# booleans) back to the recorded state, remove permissive domains and
# policy modules at priority 400 that were added since the first start
selinux_restore() {
	local rec="$REC_DIR/semanage.export" now line m before
	[ -r "$rec" ] || return 0
	now=$(semanage export 2>/dev/null) || return 0
	# Rules added since the first start go, rules removed come back
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
	# Booleans: the persistent values, then the runtime values
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

owner=$(state_value owner)
home=$(state_value home)
group=$(id -gn "$owner")

# Reset what a previous run or the solution left behind
sshd_restore
if getent passwd "$ACCOUNT" >/dev/null; then
	pkill -KILL -u "$ACCOUNT" >/dev/null 2>&1 || true
	userdel -r -f "$ACCOUNT" >/dev/null 2>&1 || true
fi
groupdel "$ACCOUNT" >/dev/null 2>&1 || true
rm -rf "$ACCOUNT_HOME"
selinux_restore
setenforce 1
sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config

# The account and its home directory under /srv, with the default type
# of that place (var_t)
if [ ! -d "$USERS_DIR" ]; then
	mkdir -m 0755 "$USERS_DIR"
fi
useradd -r -m -d "$ACCOUNT_HOME" -s /sbin/nologin \
	-c "Release deployment" "$ACCOUNT"
install -d -m 0700 -o "$ACCOUNT" -g "$ACCOUNT" "$ACCOUNT_HOME/.ssh"
install -m 0600 -o "$ACCOUNT" -g "$ACCOUNT" "$REC_DIR/key.pub" \
	"$ACCOUNT_HOME/.ssh/authorized_keys"
chmod 0777 "$ACCOUNT_HOME"
restorecon -R "$USERS_DIR"
if [ "$(stat -c %C "$ACCOUNT_HOME/.ssh/authorized_keys" | cut -d: -f3)" = ssh_home_t ]; then
	echo "Error: $ACCOUNT_HOME already has a home file context rule." >&2
	exit 1
fi

# The lab key for the task user
if [ "$(state_value key_existed)" = 0 ]; then
	install -d -m 0700 -o "$owner" -g "$group" "$home/.ssh"
	install -m 0600 -o "$owner" -g "$group" "$REC_DIR/key" "$home/.ssh/$KEY_NAME"
	install -m 0644 -o "$owner" -g "$group" "$REC_DIR/key.pub" "$home/.ssh/$KEY_NAME.pub"
	restorecon -R "$home/.ssh"
fi

# The Match block, appended to the main file. On Rocky 9 the Include of
# sshd_config.d is at the top, so the block is the last thing sshd reads
# on both releases.
printf '\n%s\n%s\n' "Match User $ACCOUNT" "    PubkeyAuthentication no" >> "$SSHD_CONFIG"
if ! sshd -t >/dev/null 2>&1; then
	cp -a "$REC_DIR/sshd_config" "$SSHD_CONFIG"
	echo "Error: sshd -t failed after the lab changed $SSHD_CONFIG." >&2
	exit 1
fi
if ! cmp -s <(sshd -T -C "user=$owner,host=localhost,addr=127.0.0.1" 2>/dev/null) \
	"$REC_DIR/owner.sshd"; then
	cp -a "$REC_DIR/sshd_config" "$SSHD_CONFIG"
	echo "Error: the lab change would alter the sshd settings of $owner." >&2
	exit 1
fi
systemctl reload sshd
exit 0
