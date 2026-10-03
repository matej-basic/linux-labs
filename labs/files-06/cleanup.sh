#!/bin/bash
# files-06 cleanup: removes what setup.sh and the solution added on both
# nodes, using the records setup.sh kept in /var/tmp/files-06.pre: the
# data tree, the archive, the extracted copy and /srv/restore on node 1,
# /srv/backup on node 2, the lab users and group, the lab key of the task
# user on node 1 and the host keys of node 2 learned during the lab, and
# the files-06-lab line in authorized_keys on node 2. Then the package
# set of the first start comes back on both nodes (rsync goes again where
# the lab installed it).
# No "set -u": load-config.sh reads variables that may be unset.

source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/packages.sh
load_lab_config

LAB=files-06
rm -f "/opt/linux-labs/state/$LAB"

# Nothing was started without multi-node support
[ "$NODES_ENABLED" = "true" ] || exit 0
[ "$NODE_COUNT" -ge 2 ] 2>/dev/null || exit 0

N1=$(get_node_ip 1)
N2=$(get_node_ip 2)

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Lab users and group, removed only when setup.sh created them and they
# still have the lab IDs
cat > "$tmp/accounts.sh" <<'REMOTE'
pre=/var/tmp/files-06.pre

had() {
	grep -qx "$1" "$pre/flags" 2>/dev/null
}

remove_accounts() {
	local u name id
	[ -d "$pre" ] || return 0
	had acct-existed && return 0
	for u in projdev:3601 projqa:3602; do
		name=${u%%:*}
		id=${u#*:}
		if [ "$(getent passwd "$name" | cut -d: -f3)" = "$id" ]; then
			userdel "$name" || return 1
			rm -f "/var/spool/mail/$name"
		fi
	done
	if [ "$(getent group projteam | cut -d: -f3)" = 3600 ]; then
		groupdel projteam || return 1
	fi
	return 0
}
REMOTE

cat > "$tmp/node1.sh" <<'REMOTE'
home=$(getent passwd "$LABU" | cut -d: -f6)
key="$home/.ssh/id_ed25519"
khu="$home/.ssh/known_hosts"
khr=/root/.ssh/known_hosts
rc=0

rm -rf /srv/projects /srv/projects.tar.xz
if [ -d "$pre" ] && ! had restore-existed; then
	rm -rf /srv/restore
else
	rm -rf /srv/restore/projects
	rmdir /srv/restore 2>/dev/null
fi

remove_accounts || rc=1

if [ -d "$pre" ] && [ -n "$home" ]; then
	if ! had key-existed; then
		rm -f "$key" "$key.pub"
	fi
	# Host keys of node 2 that the student or the solution accepted
	if ! had khu-host && [ -f "$khu" ]; then
		runuser -u "$LABU" -- ssh-keygen -R "$N2" -f "$khu" </dev/null >/dev/null 2>&1
		had khu-old-existed || rm -f "$khu.old"
		if ! had khu-existed && [ ! -s "$khu" ]; then
			rm -f "$khu"
		fi
	fi
	if ! had khr-host && [ -f "$khr" ]; then
		ssh-keygen -R "$N2" -f "$khr" </dev/null >/dev/null 2>&1
		had khr-old-existed || rm -f "$khr.old"
		if ! had khr-existed && [ ! -s "$khr" ]; then
			rm -f "$khr"
		fi
	fi
	if ! had sshdir-existed; then
		rmdir "$home/.ssh" 2>/dev/null
	fi
fi

[ "$rc" -eq 0 ] && rm -rf "$pre"
exit "$rc"
REMOTE

cat > "$tmp/node2.sh" <<'REMOTE'
home=$(getent passwd "$LABU" | cut -d: -f6)
ak="$home/.ssh/authorized_keys"
rc=0

if [ -d "$pre" ] && ! had backup-existed; then
	rm -rf /srv/backup
else
	rm -rf /srv/backup/projects
	rmdir /srv/backup 2>/dev/null
fi

remove_accounts || rc=1

# The lab line in authorized_keys, rewritten in place so that owner,
# mode and SELinux context stay
if [ -n "$home" ] && [ -f "$ak" ] && grep -q ' files-06-lab$' "$ak"; then
	t=$(mktemp)
	grep -v ' files-06-lab$' "$ak" > "$t"
	cat "$t" > "$ak" || rc=1
	rm -f "$t"
	if [ -d "$pre" ] && ! had ak-existed && [ ! -s "$ak" ]; then
		rm -f "$ak"
		had sshdir-existed || rmdir "$home/.ssh" 2>/dev/null
	fi
fi

[ "$rc" -eq 0 ] && rm -rf "$pre"
exit "$rc"
REMOTE

# send <node> <script>: run the script as root on the node
send() {
	{
		printf "LABU='%s'; N2='%s'\n" "$SSH_USER" "$N2"
		cat "$tmp/accounts.sh" "$tmp/$2"
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
