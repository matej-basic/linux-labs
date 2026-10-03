#!/bin/bash
# ssh-04 grader: the group and the accounts, the chroot directories and
# all their parents, the effective sshd configuration of ftpa, ftpb and
# the task user (sshd -T, with -C for the Match blocks), and real
# sessions with the lab key: an SFTP batch session per account that
# uploads a file, and an SSH command as ftpa that must not run. The
# clients use a throwaway known_hosts, so no known_hosts file changes.
source /opt/linux-labs/lib/grading.sh

LAB=ssh-04
GROUP=sftponly
SFTP_ROOT=/srv/sftp
STATE_FILE=/opt/linux-labs/state/$LAB
REC_DIR=/opt/linux-labs/state/$LAB.d
KEY=$REC_DIR/sftp-lab

grade_begin ssh-04
grade_require_state ssh-04 "$STATE_FILE"

state_value() {
	sed -n "s/^$1=//p" "$STATE_FILE" 2>/dev/null | head -n 1
}
owner=$(state_value owner)

# eff <user> <keyword>: the effective value of a keyword for a
# connection of <user> from localhost (Match blocks applied)
eff() {
	sshd -T -C "user=$1,host=localhost,addr=127.0.0.1" 2>/dev/null |
		awk -v k="$2" '$1 == k { $1 = ""; sub(/^ /, ""); print; exit }'
}

CLIENT_OPTS=(-F /dev/null -i "$KEY" -o IdentitiesOnly=yes -o BatchMode=yes
	-o ConnectTimeout=10 -o PreferredAuthentications=publickey
	-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
	-o GlobalKnownHostsFile=/dev/null)

group_members() {
	local u
	getent group "$GROUP" >/dev/null || return 1
	for u in ftpa ftpb; do
		id -nG "$u" 2>/dev/null | tr ' ' '\n' | grep -qx "$GROUP" || return 1
	done
}

# account_ok <user>: shell nologin, home /home/<user> exists
account_ok() {
	local shell home
	shell=$(getent passwd "$1" | cut -d: -f7)
	home=$(getent passwd "$1" | cut -d: -f6)
	case "$shell" in
	/sbin/nologin | /usr/sbin/nologin) ;;
	*) return 1 ;;
	esac
	[ "$home" = "/home/$1" ] && [ -d "$home" ]
}

# key_installed <user>: the lab public key is in the authorized keys
# file in the real home directory
key_installed() {
	local blob
	blob=$(awk '{ print $2 }' "$REC_DIR/sftp-lab.pub" 2>/dev/null)
	[ -n "$blob" ] && [ -f "/home/$1/.ssh/authorized_keys" ] &&
		grep -qF "$blob" "/home/$1/.ssh/authorized_keys"
}

# chroot_ok <user>: the chroot directory and every parent up to / are
# real directories, owned by root and not writable by group or others
chroot_ok() {
	local p="$SFTP_ROOT/$1"
	while :; do
		[ -d "$p" ] && [ ! -L "$p" ] || return 1
		[ "$(stat -c %u "$p")" = 0 ] || return 1
		[ $((0$(stat -c %a "$p") & 022)) -eq 0 ] || return 1
		[ "$p" = / ] && break
		p=$(dirname "$p")
	done
}

# upload_ok <user>: upload belongs to the user, who may write to it
upload_ok() {
	local d="$SFTP_ROOT/$1/upload"
	[ -d "$d" ] && [ ! -L "$d" ] &&
		[ "$(stat -c %U "$d")" = "$1" ] &&
		[ $((0$(stat -c %a "$d") & 0300)) -eq $((0300)) ]
}

# sshd_match <user>: chroot, forced internal-sftp, no forwarding
sshd_match() {
	case "$(eff "$1" chrootdirectory)" in
	"$SFTP_ROOT/%u" | "$SFTP_ROOT/$1") ;;
	*) return 1 ;;
	esac
	[ "$(eff "$1" forcecommand)" = internal-sftp ] &&
		[ "$(eff "$1" allowtcpforwarding)" = no ] &&
		[ "$(eff "$1" x11forwarding)" = no ]
}

owner_not_jailed() {
	[ -n "$owner" ] &&
		[ "$(eff "$owner" chrootdirectory)" = none ] &&
		[ "$(eff "$owner" forcecommand)" = none ]
}

owner_unchanged() {
	[ -n "$owner" ] && [ -s "$REC_DIR/owner.sshd" ] &&
		cmp -s <(sshd -T -C "user=$owner,host=localhost,addr=127.0.0.1" 2>/dev/null) \
			"$REC_DIR/owner.sshd"
}

sshd_running() {
	systemctl is-active --quiet sshd && systemctl is-enabled --quiet sshd
}

# sftp_session <user>: an SFTP batch session with the lab key; the
# working directory is / and a file lands in upload/
sftp_session() {
	local u="$1" tmp name rc=1 out
	[ -r "$KEY" ] || return 1
	tmp=$(mktemp -d) || return 1
	name="grade-check-$$"
	echo "$LAB" > "$tmp/$name"
	printf 'pwd\nput %s upload/%s\n' "$tmp/$name" "$name" > "$tmp/batch"
	if out=$(timeout 30 sftp "${CLIENT_OPTS[@]}" -b "$tmp/batch" \
		"$u@127.0.0.1" </dev/null 2>/dev/null); then
		if printf '%s\n' "$out" | grep -qx 'Remote working directory: /' &&
			[ -f "$SFTP_ROOT/$u/upload/$name" ] &&
			[ "$(stat -c %U "$SFTP_ROOT/$u/upload/$name")" = "$u" ]; then
			rc=0
		fi
	fi
	rm -f "$SFTP_ROOT/$u/upload/$name"
	rm -rf "$tmp"
	return "$rc"
}

# no_shell <user>: the key login succeeds, but the command does not run
no_shell() {
	local u="$1" tmp rc=1 out
	[ -r "$KEY" ] || return 1
	tmp=$(mktemp) || return 1
	# shellcheck disable=SC2016 # the remote shell would expand it
	out=$(timeout 30 ssh -v "${CLIENT_OPTS[@]}" "$u@127.0.0.1" \
		'echo shell$((40 + 2))ok' </dev/null 2>"$tmp")
	# OpenSSH 8.0 and 9.x word the debug line differently
	if grep -Eq 'Authentication succeeded \(publickey\)|Authenticated to .* using "publickey"' "$tmp" &&
		! printf '%s\n' "$out" | grep -q shell42ok; then
		rc=0
	fi
	rm -f "$tmp"
	return "$rc"
}

selinux_enforcing() {
	[ "$(getenforce 2>/dev/null)" = Enforcing ] &&
		grep -Eq '^SELINUX=enforcing[[:space:]]*$' /etc/selinux/config
}

criterion "Group $GROUP has the members ftpa and ftpb" group_members
criterion "ftpa has the shell nologin and the home /home/ftpa" account_ok ftpa
criterion "ftpb has the shell nologin and the home /home/ftpb" account_ok ftpb
criterion "The lab key is in authorized_keys of ftpa" key_installed ftpa
criterion "The lab key is in authorized_keys of ftpb" key_installed ftpb
criterion "$SFTP_ROOT/ftpa and its parents are root-owned, not writable" chroot_ok ftpa
criterion "$SFTP_ROOT/ftpb and its parents are root-owned, not writable" chroot_ok ftpb
criterion "$SFTP_ROOT/ftpa/upload is owned and writable by ftpa" upload_ok ftpa
criterion "$SFTP_ROOT/ftpb/upload is owned and writable by ftpb" upload_ok ftpb
criterion "sshd settings for ftpa: chroot, internal-sftp, no forwarding" sshd_match ftpa
criterion "sshd settings for ftpb: chroot, internal-sftp, no forwarding" sshd_match ftpb
criterion "No chroot and no forced command for $owner" owner_not_jailed
criterion "The sshd settings for $owner are unchanged" owner_unchanged
criterion "The sshd configuration passes the syntax test" sshd -t
criterion "sshd is enabled and running" sshd_running
criterion "SFTP as ftpa with the lab key works in the chroot" sftp_session ftpa
criterion "SFTP as ftpb with the lab key works in the chroot" sftp_session ftpb
criterion "A command over SSH as ftpa does not run" no_shell ftpa
criterion "SELinux is enforcing now and in /etc/selinux/config" selinux_enforcing
grade_end
