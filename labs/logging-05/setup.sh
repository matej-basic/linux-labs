#!/bin/bash
# logging-05 setup: records on both nodes what the lab may change, so
# that cleanup.sh puts it back: a copy of /etc/rsyslog.conf and of the
# directory /etc/rsyslog.d, the file names in the rsyslog work directory
# /var/lib/rsyslog (queue spool files appear there), whether
# /var/log/remote existed, the ports and services of every firewalld
# zone (runtime and permanent) and the unit state of rsyslog. The records
# live in /var/tmp/logging-05.pre on each node, the package set in the
# snapshot of lib/packages.sh. A restart first runs cleanup.sh, so every
# start begins from the state before the lab.
# Prints nothing on success.
# No "set -u": load-config.sh reads variables that may be unset.
set -e

source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/packages.sh
load_lab_config

LAB=logging-05
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"

if [ "$NODES_ENABLED" != "true" ]; then
	echo "$LAB needs multi-node labs: run 'sudo labctl configure interactive' and enable them" >&2
	exit 1
fi
if [ "$NODE_COUNT" -lt 2 ] 2>/dev/null; then
	echo "$LAB needs 2 nodes, NODE_COUNT is $NODE_COUNT: run 'sudo labctl configure set NODE_COUNT 2'" >&2
	exit 1
fi

N1=$(get_node_ip 1)
N2=$(get_node_ip 2)
for n in 1 2; do
	ip=$(get_node_ip "$n")
	if ! test_node_connectivity "$ip" >/dev/null; then
		echo "Cannot reach node $n ($ip) over SSH as $SSH_USER" >&2
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

cat > "$tmp/node.sh" <<'REMOTE'
pre=/var/tmp/logging-05.pre

if ! rpm -q rsyslog >/dev/null 2>&1 || [ ! -f /etc/rsyslog.conf ]; then
	echo "rsyslog is not installed" >&2
	exit 1
fi
if ! firewall-cmd --state >/dev/null 2>&1; then
	echo "firewalld is not running" >&2
	exit 1
fi

# fw_dump [--permanent]: one line "<zone> <port|service> <value>" for
# every port and service of every zone
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
cp -a /etc/rsyslog.conf "$pre.tmp/rsyslog.conf" || exit 1
if [ -d /etc/rsyslog.d ]; then
	cp -a /etc/rsyslog.d "$pre.tmp/rsyslog.d" || exit 1
fi
mkdir -p /var/lib/rsyslog
ls -A /var/lib/rsyslog > "$pre.tmp/workdir" || exit 1
fw_dump > "$pre.tmp/fw.runtime" || exit 1
fw_dump --permanent > "$pre.tmp/fw.permanent" || exit 1
{
	[ -e /var/log/remote ] && echo remote-existed
	systemctl is-enabled --quiet rsyslog && echo rsyslog-enabled
	systemctl is-active --quiet rsyslog && echo rsyslog-active
} > "$pre.tmp/flags"
mv "$pre.tmp" "$pre" || exit 1
exit 0
REMOTE

for n in 1 2; do
	ip=$(get_node_ip "$n")
	if ! pkg_snapshot_node "$ip" "$LAB" > "$tmp/out" 2>&1; then
		echo "Recording the packages of node $n ($ip) failed:" >&2
		cat "$tmp/out" >&2
		exit 1
	fi
	if ! run_on_node "$ip" "sudo -n bash -s" < "$tmp/node.sh" > /dev/null 2> "$tmp/err"; then
		echo "Preparing node $n ($ip) failed:" >&2
		grep -v "^Warning: Permanently added" "$tmp/err" >&2
		exit 1
	fi
done

mkdir -p "$STATE_DIR"
printf 'node1=%s\nnode2=%s\n' "$N1" "$N2" > "$STATE_FILE"
chmod 0644 "$STATE_FILE"
