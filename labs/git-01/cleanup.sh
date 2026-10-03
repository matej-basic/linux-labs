#!/bin/bash
# git-01 cleanup: with the records setup.sh kept in /var/tmp/git-01.pre
# on each node. Node 1: the user and group git with /home/git and its
# mail spool, /srv/git, and /etc/shells as it was. Node 2: ~/project of
# the node account, the lab key, the host keys of node 1 learned during
# the lab and ~/.gitconfig as it was. Then the package set of the first
# start comes back on both nodes (git goes again).
# A node without records was never prepared and is left alone.
# No "set -u": load-config.sh reads variables that may be unset.

source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/packages.sh
load_lab_config

LAB=git-01
rm -f "/opt/linux-labs/state/$LAB"

# Nothing was started without multi-node support
[ "$NODES_ENABLED" = "true" ] || exit 0
[ "$NODE_COUNT" -ge 2 ] 2>/dev/null || exit 0

N1=$(get_node_ip 1)
N2=$(get_node_ip 2)

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/node1.sh" <<'REMOTE'
pre=/var/tmp/git-01.pre
[ -d "$pre" ] || exit 0
rc=0

# Setup refused to start when git existed, so the account is the lab's
if getent passwd git >/dev/null; then
	pkill -KILL -u git 2>/dev/null && sleep 1
	userdel -r git >/dev/null 2>&1
	if getent passwd git >/dev/null; then
		echo "the user git could not be removed" >&2
		rc=1
	fi
fi
if getent group git >/dev/null; then
	groupdel git || rc=1
fi
rm -rf /home/git /var/spool/mail/git /srv/git

# /etc/shells rewritten in place, so that owner, mode and context stay
if [ -f "$pre/shells" ] && ! cmp -s "$pre/shells" /etc/shells; then
	cat "$pre/shells" > /etc/shells || rc=1
fi

[ "$rc" -eq 0 ] && rm -rf "$pre"
exit "$rc"
REMOTE

cat > "$tmp/node2.sh" <<'REMOTE'
pre=/var/tmp/git-01.pre
[ -d "$pre" ] || exit 0
home=$(getent passwd "$LABU" | cut -d: -f6)
[ -n "$home" ] || exit 0
key="$home/.ssh/id_ed25519"
khu="$home/.ssh/known_hosts"
khr=/root/.ssh/known_hosts
rc=0

had() {
	grep -qx "$1" "$pre/flags" 2>/dev/null
}

rm -rf "$home/project"

if had gitconfig-existed; then
	if [ -f "$pre/gitconfig" ]; then
		cp -a "$pre/gitconfig" "$home/.gitconfig" || rc=1
	fi
else
	rm -f "$home/.gitconfig"
fi

had key-existed || rm -f "$key" "$key.pub"

# Host keys of node 1 that the student or the solution accepted
if ! had khu-host && [ -f "$khu" ]; then
	runuser -u "$LABU" -- ssh-keygen -R "$N1" -f "$khu" </dev/null >/dev/null 2>&1
	had khu-old-existed || rm -f "$khu.old"
	if ! had khu-existed && [ ! -s "$khu" ]; then
		rm -f "$khu"
	fi
fi
if ! had khr-host && [ -f "$khr" ]; then
	ssh-keygen -R "$N1" -f "$khr" </dev/null >/dev/null 2>&1
	had khr-old-existed || rm -f "$khr.old"
	if ! had khr-existed && [ ! -s "$khr" ]; then
		rm -f "$khr"
	fi
fi
had sshdir-existed || rmdir "$home/.ssh" 2>/dev/null

[ "$rc" -eq 0 ] && rm -rf "$pre"
exit "$rc"
REMOTE

# send <node> <script>: run the script as root on the node
send() {
	{
		printf "LABU='%s'; N1='%s'\n" "$SSH_USER" "$N1"
		cat "$tmp/$2"
	} | run_on_node "$1" "sudo -n bash -s"
}

rc=0
n=0
for ip in "$N1" "$N2"; do
	n=$((n + 1))
	if ! send "$ip" "node$n.sh" > /dev/null 2> "$tmp/err"; then
		echo "Cleanup of node $n ($ip) failed:" >&2
		grep -v "^Warning: Permanently added" "$tmp/err" >&2
		rc=1
		continue
	fi
	if ! pkg_restore_node "$ip" "$LAB" 2> "$tmp/err"; then
		echo "Restoring the packages of node $n ($ip) failed:" >&2
		grep -v "^Warning: Permanently added" "$tmp/err" >&2
		rc=1
	fi
done
exit "$rc"
