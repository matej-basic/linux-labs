#!/bin/bash
# nfs-01 setup: puts nodes 1 and 2 into the starting state. Node 1 has
# the directory /srv/nfsshare with one file, owned by root, no export of
# it, the NFS server stopped and disabled and no NFS rule in the
# firewall. Node 2 has no mount at /mnt/nfsshare and no fstab entry for
# it. Prints nothing on success.
#
# The first run records each node's package set (lib/packages.sh), so
# that cleanup.sh removes nfs-utils and rpcbind again where the lab
# installed them. On node 1 it also records in /var/tmp/nfs-01.pre the
# boot and running state of nfs-server, the NFS firewall services and a
# copy of /etc/exports, so that cleanup.sh puts back a server that
# existed before the lab.
# No "set -u": load-config.sh reads variables that may be unset.
set -e

source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/packages.sh
load_lab_config

LAB=nfs-01
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"

if [ "$NODES_ENABLED" != "true" ]; then
	echo "$LAB needs multi-node labs: run 'sudo labctl configure interactive' and enable them" >&2
	exit 1
fi
if ! [ "$NODE_COUNT" -ge 2 ] 2>/dev/null; then
	echo "$LAB needs 2 nodes, NODE_COUNT is $NODE_COUNT: run 'sudo labctl configure set NODE_COUNT 2'" >&2
	exit 1
fi

for n in 1 2; do
	ip=$(get_node_ip "$n")
	if ! test_node_connectivity "$ip" >/dev/null; then
		echo "Cannot reach node $n ($ip) over SSH as $SSH_USER" >&2
		exit 1
	fi
done

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Node 2, the client: no mount and no fstab entry at /mnt/nfsshare.
# Runs as root through "bash -s", so every command that could read
# stdin gets /dev/null instead of the script.
cat > "$tmp/client.sh" <<'REMOTE'
mp=/mnt/nfsshare

if mountpoint -q "$mp" 2>/dev/null; then
	umount "$mp" </dev/null >/dev/null 2>&1 ||
		umount -f -l "$mp" </dev/null >/dev/null 2>&1
fi
if mountpoint -q "$mp" 2>/dev/null; then
	echo "cannot unmount $mp" >&2
	exit 1
fi
if awk -v m="$mp" '$1 !~ /^#/ && ($2 == m || $2 == m "/") { f = 1 } END { exit !f }' /etc/fstab; then
	awk -v m="$mp" '$1 ~ /^#/ || ($2 != m && $2 != m "/")' /etc/fstab > /etc/fstab.nfs-01 || exit 1
	cat /etc/fstab.nfs-01 > /etc/fstab || exit 1
	rm -f /etc/fstab.nfs-01
	systemctl daemon-reload </dev/null >/dev/null 2>&1
fi
rm -rf --one-file-system "$mp"
exit 0
REMOTE

# Node 1, the server: record the state from before the lab once, then
# remove the export, stop the NFS server, close the firewall and create
# the directory with its file.
cat > "$tmp/server.sh" <<'REMOTE'
pre=/var/tmp/nfs-01.pre
dir=/srv/nfsshare

if [ ! -d "$pre" ]; then
	rm -rf "$pre.tmp"
	mkdir -m 0700 "$pre.tmp" || exit 1
	{
		systemctl is-enabled --quiet nfs-server 2>/dev/null && echo nfs-server-enabled
		systemctl is-active --quiet nfs-server 2>/dev/null && echo nfs-server-active
		for s in nfs mountd rpc-bind; do
			firewall-cmd --permanent --query-service="$s" </dev/null >/dev/null 2>&1 && echo "fw-$s"
		done
	} > "$pre.tmp/flags"
	if [ -f /etc/exports ]; then
		cp -a /etc/exports "$pre.tmp/exports" || exit 1
	fi
	mv "$pre.tmp" "$pre" || exit 1
fi

# No export of the lab directory in /etc/exports or /etc/exports.d
for f in /etc/exports /etc/exports.d/*.exports; do
	[ -f "$f" ] || continue
	if awk -v d="$dir" '$1 == d || $1 == d "/" { f = 1 } END { exit !f }' "$f"; then
		awk -v d="$dir" '$1 != d && $1 != d "/"' "$f" > "$f.nfs-01" || exit 1
		cat "$f.nfs-01" > "$f" || exit 1
		rm -f "$f.nfs-01"
	fi
done
if systemctl cat nfs-server </dev/null >/dev/null 2>&1; then
	command -v exportfs >/dev/null 2>&1 && exportfs -ua </dev/null >/dev/null 2>&1
	systemctl disable --now nfs-server </dev/null >/dev/null 2>&1
fi

if systemctl is-active --quiet firewalld; then
	for s in nfs mountd rpc-bind; do
		firewall-cmd --permanent --remove-service="$s" </dev/null >/dev/null 2>&1
	done
	firewall-cmd --reload </dev/null >/dev/null 2>&1 || {
		echo "firewall-cmd --reload failed" >&2
		exit 1
	}
fi

rm -rf --one-file-system "$dir"
mkdir -p "$dir" || exit 1
echo "This file is shared from node 1." > "$dir/welcome.txt" || exit 1
chown -R root:root "$dir"
chmod 0755 "$dir"
chmod 0644 "$dir/welcome.txt"
restorecon -R "$dir" >/dev/null 2>&1
exit 0
REMOTE

# Client first, so that no mount hangs on a server that goes away
for n in 2 1; do
	ip=$(get_node_ip "$n")
	if ! pkg_snapshot_node "$ip" "$LAB" > "$tmp/out" 2>&1; then
		echo "Recording the packages of node $n ($ip) failed:" >&2
		cat "$tmp/out" >&2
		exit 1
	fi
	if [ "$n" = 2 ]; then script="$tmp/client.sh"; else script="$tmp/server.sh"; fi
	if ! run_on_node "$ip" "sudo -n bash -s" < "$script" > "$tmp/out" 2>&1; then
		echo "Preparing node $n ($ip) failed:" >&2
		cat "$tmp/out" >&2
		exit 1
	fi
done

# The grader checks that the lab was started
mkdir -p "$STATE_DIR"
echo "nodes=$(get_node_ip 1) $(get_node_ip 2)" > "$STATE_FILE"
chmod 0644 "$STATE_FILE"
