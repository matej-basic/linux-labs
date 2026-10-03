#!/bin/bash
# storage-09 setup: records on both nodes what the lab may change, so
# that cleanup.sh puts it back. Node 1, the target, keeps in
# /var/tmp/storage-09.pre a copy of /etc/target, the ports and services
# of every firewalld zone (runtime and permanent), the unit state of
# target.service and whether /srv/iscsi and /root/.targetcli existed.
# Node 2, the initiator, keeps a copy of /etc/iscsi/initiatorname.iscsi
# and whether /etc/iscsi, /var/lib/iscsi and /mnt/iscsi existed. The
# package set of both nodes goes into the snapshot of lib/packages.sh.
# A restart first runs cleanup.sh, so every start begins from the state
# before the lab: no lab target on node 1, no session, mount or fstab
# entry of the lab on node 2.
# Prints nothing on success.
# No "set -u": load-config.sh reads variables that may be unset.
set -e

source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/packages.sh
load_lab_config

LAB=storage-09
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

N1=$(get_node_ip 1)
N2=$(get_node_ip 2)
for ip in "$N1" "$N2"; do
	if ! test_node_connectivity "$ip" >/dev/null; then
		echo "Cannot reach node $ip over SSH as $SSH_USER" >&2
		exit 1
	fi
done

# Undo an earlier start and its solution first. cleanup.sh does nothing
# on a node without records.
if ! bash "$(dirname "$0")/cleanup.sh"; then
	echo "Undoing an earlier start of $LAB failed." >&2
	exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Node 1, the target. Runs as root through "bash -s".
cat > "$tmp/node1.sh" <<'REMOTE'
pre=/var/tmp/storage-09.pre

if ! firewall-cmd --state >/dev/null 2>&1; then
	echo "firewalld is not running" >&2
	exit 1
fi

fw_dump() {
	firewall-cmd "$@" --list-all-zones | awk '
		/^[^ \t]/ { zone = $1 }
		/^[ \t]+services:/ { for (i = 2; i <= NF; i++) print zone, "service", $i }
		/^[ \t]+ports:/ { for (i = 2; i <= NF; i++) print zone, "port", $i }
	' | LC_ALL=C sort
}

[ -d "$pre" ] && exit 0
rm -rf "$pre.tmp"
mkdir -m 0700 "$pre.tmp" || exit 1
if [ -d /etc/target ]; then
	cp -a /etc/target "$pre.tmp/target" || exit 1
fi
fw_dump > "$pre.tmp/fw.runtime" || exit 1
fw_dump --permanent > "$pre.tmp/fw.permanent" || exit 1
{
	[ -e /srv/iscsi ] && echo srv-existed
	[ -e /root/.targetcli ] && echo targetcli-home-existed
	systemctl is-enabled --quiet target 2>/dev/null && echo target-enabled
	systemctl is-active --quiet target 2>/dev/null && echo target-active
} > "$pre.tmp/flags"
mv "$pre.tmp" "$pre" || exit 1
exit 0
REMOTE

# Node 2, the initiator
cat > "$tmp/node2.sh" <<'REMOTE'
pre=/var/tmp/storage-09.pre

[ -d "$pre" ] && exit 0
rm -rf "$pre.tmp"
mkdir -m 0700 "$pre.tmp" || exit 1
if [ -f /etc/iscsi/initiatorname.iscsi ]; then
	cp -a /etc/iscsi/initiatorname.iscsi "$pre.tmp/initiatorname.iscsi" || exit 1
fi
{
	[ -e /etc/iscsi ] && echo etc-iscsi-existed
	[ -e /var/lib/iscsi ] && echo var-iscsi-existed
	[ -e /mnt/iscsi ] && echo mnt-existed
} > "$pre.tmp/flags"
mv "$pre.tmp" "$pre" || exit 1
exit 0
REMOTE

for n in 1 2; do
	ip=$(get_node_ip "$n")
	if ! pkg_snapshot_node "$ip" "$LAB" > "$tmp/out" 2>&1; then
		echo "Recording the packages of node $n ($ip) failed:" >&2
		grep -v "^Warning: Permanently added" "$tmp/out" >&2
		exit 1
	fi
	if ! run_on_node "$ip" "sudo -n bash -s" < "$tmp/node$n.sh" > /dev/null 2> "$tmp/err"; then
		echo "Preparing node $n ($ip) failed:" >&2
		grep -v "^Warning: Permanently added" "$tmp/err" >&2
		exit 1
	fi
done

mkdir -p "$STATE_DIR"
printf 'node1=%s\nnode2=%s\n' "$N1" "$N2" > "$STATE_FILE"
chmod 0644 "$STATE_FILE"
