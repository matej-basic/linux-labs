#!/bin/bash
# ansible-03 cleanup: puts nodes 1 to 3 back into the state that the
# first setup.sh run recorded.
#
# Node 1: the SSH connections Ansible keeps open end, ~/ansible-lab and
# ~/appadmin-password.txt go, ~/.ansible goes unless it existed before,
# files in ~/.ssh that were not there before go (authorized_keys is
# never touched) and known_hosts comes back as recorded. Then the
# package set of the first start comes back (lib/packages.sh), which
# removes ansible-core again.
# Nodes 2 and 3: the users appadmin and ansible, the sudoers drop-in,
# the lab groups that did not exist before and the custom fact go, and
# /etc/motd comes back as recorded. Then the package set comes back,
# which removes zsh, and /etc/ansible goes where the lab created it.
# When a node cannot be restored, its records stay for the next reset
# and the exit status is 1.
# No "set -u": load-config.sh reads variables that may be unset.

source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/packages.sh
load_lab_config

LAB=ansible-03
STATE_FILE="/opt/linux-labs/state/$LAB"

# Nothing was started without multi-node support
if [ "$NODES_ENABLED" != "true" ] || ! [ "$NODE_COUNT" -ge 3 ] 2>/dev/null; then
	rm -f "$STATE_FILE"
	exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Node 1 before the package restore
cat > "$tmp/control.sh" <<'REMOTE'
u=$1
pre=/var/tmp/ansible-03.pre
[ -d "$pre" ] || exit 0
home=$(getent passwd "$u" | cut -d: -f6)
[ -n "$home" ] && [ -d "$home" ] || exit 0

pkill -u "$u" -f '\.ansible/cp/' </dev/null >/dev/null 2>&1

rm -rf --one-file-system "$home/ansible-lab"
rm -f "$home/appadmin-password.txt"
grep -qx ansible-dir "$pre/flags" || rm -rf --one-file-system "$home/.ansible"
if [ -d "$home/.ssh" ]; then
	for f in "$home/.ssh"/* "$home/.ssh"/.[!.]*; do
		[ -e "$f" ] || [ -L "$f" ] || continue
		n=${f##*/}
		[ "$n" = authorized_keys ] && continue
		grep -qxF -- "$n" "$pre/ssh-files" || rm -rf -- "$f"
	done
	if [ -f "$pre/known_hosts" ]; then
		cp -a "$pre/known_hosts" "$home/.ssh/known_hosts" || exit 1
	fi
	grep -qx ssh-dir "$pre/flags" || rmdir "$home/.ssh" 2>/dev/null
fi
exit 0
REMOTE

# Node 1 after the package restore: what ansible-core leaves behind
cat > "$tmp/control-post.sh" <<'REMOTE'
pre=/var/tmp/ansible-03.pre
[ -d "$pre" ] || exit 0
for d in /etc/ansible /usr/share/ansible; do
	if [ -d "$d" ] && ! rpm -qf "$d" >/dev/null 2>&1; then
		rm -rf --one-file-system "$d"
	fi
done
rm -rf "$pre"
exit 0
REMOTE

# Nodes 2 and 3 before the package restore
cat > "$tmp/managed.sh" <<'REMOTE'
pre=/var/tmp/ansible-03.pre
mark="linux-labs ansible-03"
[ -d "$pre" ] || exit 0

# deluser <name>: end the user's processes and remove it with its home
deluser() {
	local i
	getent passwd "$1" >/dev/null || return 0
	for i in 1 2 3 4 5; do
		pkill -KILL -u "$1" </dev/null >/dev/null 2>&1
		sleep 1
		userdel -r "$1" </dev/null >/dev/null 2>&1 && break
	done
	if getent passwd "$1" >/dev/null; then
		echo "cannot remove the user $1" >&2
		exit 1
	fi
}

deluser appadmin
for g in appdev appops appaudit appadmin; do
	grep -qxF "$g" "$pre/groups" 2>/dev/null && continue
	if getent group "$g" >/dev/null; then
		groupdel "$g" || exit 1
	fi
done

if getent passwd ansible >/dev/null &&
	[ "$(getent passwd ansible | cut -d: -f5)" = "$mark" ]; then
	deluser ansible
fi
rm -f /etc/sudoers.d/ansible-03 /etc/sudoers.d/.ansible-03.tmp

rm -f /etc/ansible/facts.d/lab.fact
if [ -f "$pre/motd" ]; then
	cp -a "$pre/motd" /etc/motd || exit 1
else
	rm -f /etc/motd
fi
exit 0
REMOTE

# Nodes 2 and 3 after the package restore: /etc/ansible where the lab
# created it
cat > "$tmp/managed-post.sh" <<'REMOTE'
pre=/var/tmp/ansible-03.pre
[ -d "$pre" ] || exit 0
if ! grep -qx facts-dir "$pre/flags"; then
	rmdir /etc/ansible/facts.d 2>/dev/null
fi
if ! grep -qx etc-ansible "$pre/flags" && ! rpm -qf /etc/ansible >/dev/null 2>&1; then
	rmdir /etc/ansible 2>/dev/null
fi
rm -rf "$pre"
exit 0
REMOTE

user_arg=$(printf '%q' "$SSH_USER")
rc=0
for n in 1 2 3; do
	ip=$(get_node_ip "$n")
	if [ "$n" = 1 ]; then
		stop="$tmp/control.sh"
		post="$tmp/control-post.sh"
	else
		stop="$tmp/managed.sh"
		post="$tmp/managed-post.sh"
	fi
	if ! run_on_node "$ip" "sudo -n bash -s -- $user_arg" < "$stop" > "$tmp/out" 2>&1; then
		echo "Cleanup of node $n ($ip) failed:" >&2
		grep -v "^Warning: Permanently added" "$tmp/out" >&2
		rc=1
		continue
	fi
	pkg_restore_node "$ip" "$LAB" 2>"$tmp/err" || {
		echo "Restoring the packages of node $n ($ip) failed:" >&2
		grep -v "^Warning: Permanently added" "$tmp/err" >&2
		# Keep the records of this node for the next reset
		rc=1
		continue
	}
	if ! run_on_node "$ip" "sudo -n bash -s" < "$post" > "$tmp/out" 2>&1; then
		echo "Cleanup of node $n ($ip) failed:" >&2
		grep -v "^Warning: Permanently added" "$tmp/out" >&2
		rc=1
	fi
done

[ "$rc" -eq 0 ] && rm -f "$STATE_FILE"
exit "$rc"
