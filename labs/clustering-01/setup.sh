#!/bin/bash
# clustering-01 setup: puts the three cluster nodes into a clean starting
# state (no cluster, no cluster packages) and records what was installed
# before, so cleanup.sh removes only what the lab added. Prints nothing
# on success.
set -e
# load-config.sh reads unset variables, so it is sourced before set -u
source /opt/linux-labs/lib/load-config.sh
set -u

LAB=clustering-01
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"

die() {
	echo "Error: $LAB setup: $*" >&2
	exit 1
}

# Run a script on a node as root. The script travels base64-encoded in the
# command line, so its standard input stays free for the programs in it.
run_script() {
	local ip="$1" script="$2" b64
	shift 2
	b64=$(printf '%s' "$script" | base64 | tr -d '\n')
	run_on_node "$ip" "sudo bash -c \"\$(echo $b64 | base64 -d)\" _ $*" </dev/null
}

[ "$NODES_ENABLED" = true ] ||
	die "multi-node labs are not enabled. Run: sudo labctl configure interactive"
[ "$NODE_COUNT" -ge 3 ] ||
	die "this lab needs 3 nodes (NODE_COUNT is $NODE_COUNT). Run: sudo labctl configure set NODE_COUNT 3"

IPS="$(get_node_ip 1) $(get_node_ip 2) $(get_node_ip 3)"

n=0
for ip in $IPS; do
	n=$((n + 1))
	test_node_connectivity "$ip" >/dev/null ||
		die "node $n ($ip) is not reachable over SSH as $SSH_USER with key $SSH_KEY_PATH"
	run_script "$ip" 'true' >/dev/null 2>&1 ||
		die "user $SSH_USER has no passwordless sudo on node $n ($ip)"
done

# What the nodes had before the lab (runs on the node as root)
PROBE='
if rpm -q httpd >/dev/null 2>&1; then echo httpd=present; else echo httpd=absent; fi
if command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1 &&
	firewall-cmd --permanent --query-service=high-availability >/dev/null 2>&1; then
	echo hafw=present
else
	echo hafw=absent
fi
'

# Starting state of a node (runs on the node as root): no cluster, no
# cluster packages, no leftover cluster configuration or page.
RESET='
if command -v pcs >/dev/null 2>&1; then pcs cluster destroy >/dev/null 2>&1 || true; fi
systemctl disable --now pacemaker corosync pcsd >/dev/null 2>&1 || true
if grep -qs "HA Cluster" /var/www/html/index.html; then rm -f /var/www/html/index.html; fi
dnf -y -q remove pacemaker corosync pcs >/dev/null 2>&1 || true
rm -f /etc/corosync/corosync.conf /etc/corosync/authkey
rm -f /var/lib/pcsd/known-hosts /var/lib/pcsd/tokens /var/lib/pcsd/pcs_settings.conf
rm -rf /var/lib/pacemaker/cib/* /var/lib/pacemaker/pengine/* /var/lib/corosync/*
if id hacluster >/dev/null 2>&1; then passwd -l hacluster >/dev/null 2>&1 || true; fi
exit 0
'

# Record the starting state once; a second start keeps the first record
if [ ! -f "$STATE_FILE" ]; then
	tmp=$(mktemp)
	n=0
	for ip in $IPS; do
		n=$((n + 1))
		out=$(run_script "$ip" "$PROBE" 2>/dev/null) ||
			die "cannot inspect node $n ($ip)"
		printf '%s\n' "$out" | sed "s/^/node${n}_/" >> "$tmp"
	done
	mkdir -p "$STATE_DIR"
	mv "$tmp" "$STATE_FILE"
	chmod 644 "$STATE_FILE"
fi

n=0
for ip in $IPS; do
	n=$((n + 1))
	run_script "$ip" "$RESET" >/dev/null 2>&1 ||
		die "cannot reset node $n ($ip)"
done
