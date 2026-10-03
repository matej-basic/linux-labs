#!/bin/bash
# ssh-03 grader: a real key login as webdeploy with the lab key, the
# effective sshd configuration (sshd -T, with -C for the Match blocks),
# the account, the modes and SELinux labels in its home directory, the
# SELinux mode and the sshd configuration of the task user compared with
# the copy setup.sh made at the first start.
source /opt/linux-labs/lib/grading.sh

LAB=ssh-03
ACCOUNT=webdeploy
ACCOUNT_HOME=/srv/users/$ACCOUNT
STATE_FILE=/opt/linux-labs/state/$LAB
REC_DIR=/opt/linux-labs/state/$LAB.d
KEY=$REC_DIR/key

grade_begin ssh-03
grade_require_state ssh-03 "$STATE_FILE"

state_value() {
	sed -n "s/^$1=//p" "$STATE_FILE" 2>/dev/null | head -n 1
}
owner=$(state_value owner)

# eff <user> <keyword>: the effective value of a keyword for a
# connection of <user> from localhost (Match blocks applied)
eff() {
	sshd -T -C "user=$1,host=localhost,addr=127.0.0.1" 2>/dev/null |
		awk -v k="$2" '$1 == k { print $2; exit }'
}

# A batch-mode key login as webdeploy on 127.0.0.1 with the lab key
key_login() {
	[ -r "$KEY" ] || return 1
	[ "$(ssh -F /dev/null -i "$KEY" -o IdentitiesOnly=yes \
		-o BatchMode=yes -o ConnectTimeout=10 -o LogLevel=ERROR \
		-o PreferredAuthentications=publickey \
		-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
		-o GlobalKnownHostsFile=/dev/null \
		"$ACCOUNT@127.0.0.1" id -un </dev/null 2>/dev/null)" = "$ACCOUNT" ]
}

pubkey_on() {
	[ "$(eff "$ACCOUNT" pubkeyauthentication)" = yes ]
}

strictmodes_on() {
	[ "$(eff "$ACCOUNT" strictmodes)" = yes ]
}

shell_bash() {
	[ "$(getent passwd "$ACCOUNT" | cut -d: -f7)" = /bin/bash ]
}

# The home directory belongs to webdeploy and is not writable by the
# group or by others
home_ok() {
	[ -d "$ACCOUNT_HOME" ] &&
		[ "$(stat -c %U "$ACCOUNT_HOME")" = "$ACCOUNT" ] &&
		[ $((0$(stat -c %a "$ACCOUNT_HOME") & 022)) -eq 0 ]
}

# mode_owner <path> <type> <mode>
mode_owner() {
	[ ! -L "$1" ] || return 1
	case $2 in
	d) [ -d "$1" ] || return 1 ;;
	f) [ -f "$1" ] || return 1 ;;
	esac
	[ "$(stat -c '%U %a' "$1")" = "$ACCOUNT $3" ]
}

# The file context rules give every path in the home directory the
# label it has (restorecon in dry-run mode would change nothing)
labels_persistent() {
	local out
	[ -d "$ACCOUNT_HOME" ] || return 1
	out=$(restorecon -n -R -v "$ACCOUNT_HOME" 2>&1) || return 1
	[ -z "$out" ]
}

keys_type() {
	[ "$(stat -c %C "$ACCOUNT_HOME/.ssh/authorized_keys" 2>/dev/null |
		cut -d: -f3)" = ssh_home_t ]
}

selinux_enforcing() {
	[ "$(getenforce 2>/dev/null)" = Enforcing ] &&
		grep -Eq '^SELINUX=enforcing[[:space:]]*$' /etc/selinux/config
}

# No permissive domain that was not there at the first start
no_permissive_added() {
	local now
	now=$(semanage permissive -l 2>/dev/null | awk 'NF == 1 { print $1 }' | sort -u)
	[ -r "$REC_DIR/permissive" ] || return 1
	! printf '%s\n' "$now" | grep -vxF -f "$REC_DIR/permissive" | grep -q .
}

sshd_running() {
	systemctl is-active --quiet sshd && systemctl is-enabled --quiet sshd
}

owner_unchanged() {
	[ -n "$owner" ] && [ -s "$REC_DIR/owner.sshd" ] &&
		cmp -s <(sshd -T -C "user=$owner,host=localhost,addr=127.0.0.1" 2>/dev/null) \
			"$REC_DIR/owner.sshd"
}

criterion "Key login as $ACCOUNT with the lab key works" key_login
criterion "Public key authentication is on for $ACCOUNT" pubkey_on
criterion "StrictModes is on" strictmodes_on
criterion "The login shell of $ACCOUNT is /bin/bash" shell_bash
criterion "$ACCOUNT_HOME is owned by $ACCOUNT, no group/other write" home_ok
criterion "$ACCOUNT_HOME/.ssh is owned by $ACCOUNT, mode 0700" \
	mode_owner "$ACCOUNT_HOME/.ssh" d 700
criterion "authorized_keys is owned by $ACCOUNT, mode 0600" \
	mode_owner "$ACCOUNT_HOME/.ssh/authorized_keys" f 600
criterion "authorized_keys has the SELinux type ssh_home_t" keys_type
criterion "The file context rules match the labels in $ACCOUNT_HOME" labels_persistent
criterion "SELinux is enforcing now and in /etc/selinux/config" selinux_enforcing
criterion "No permissive domains were added" no_permissive_added
criterion "The sshd configuration passes the syntax test" sshd -t
criterion "sshd is enabled and running" sshd_running
criterion "The sshd settings for $owner are unchanged" owner_unchanged
grade_end
