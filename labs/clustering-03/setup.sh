#!/bin/bash
# clustering-03 setup: checks that the clustering-01/02 cluster is up,
# removes votequorum options left by an earlier attempt, and sets the
# cluster property no-quorum-policy to ignore (the unsafe starting
# state). Prints nothing on success.

# load-config.sh is not safe under "set -u", so source it first.
source /opt/linux-labs/lib/load-config.sh
load_lab_config
set -eu

LAB=clustering-03
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
CONF=/etc/corosync/corosync.conf

die() {
	echo "$LAB: $*" >&2
	exit 1
}

[ "$NODES_ENABLED" = true ] ||
	die "multi-node labs are not enabled (run: sudo labctl configure interactive)"
[ "$NODE_COUNT" -ge 3 ] ||
	die "this lab needs 3 nodes, NODE_COUNT is $NODE_COUNT (run: sudo labctl configure set NODE_COUNT 3)"

ips=("$(get_node_ip 1)" "$(get_node_ip 2)" "$(get_node_ip 3)")

# Run a command on a node without ssh noise on stderr
on_node() {
	run_on_node "$@" 2>/dev/null
}

for ip in "${ips[@]}"; do
	test_node_connectivity "$ip" >/dev/null ||
		die "cannot reach node $ip over SSH (check the lab configuration)"
	for unit in corosync pacemaker; do
		on_node "$ip" "sudo systemctl is-active --quiet $unit" ||
			die "$unit is not running on $ip; complete clustering-01 and clustering-02 first"
	done
done

# Wait until every node reports 3 members
wait_members() {
	local i ip
	for ip in "${ips[@]}"; do
		for i in $(seq 1 60); do
			on_node "$ip" "sudo corosync-quorumtool -s | grep -Eq '^Nodes:[[:space:]]+3\$'" && break
			sleep 2
		done
		[ "$i" -lt 60 ] || return 1
	done
}

# Remove votequorum options with a non-zero value (left behind by an
# earlier attempt), then restart the changed nodes one at a time so
# the cluster keeps quorum.
changed=()
for ip in "${ips[@]}"; do
	if on_node "$ip" "sudo grep -Eq '^[[:space:]]*(wait_for_all|last_man_standing|last_man_standing_window):[[:space:]]*[1-9]' $CONF"; then
		on_node "$ip" "sudo sed -i -E '/^[[:space:]]*(wait_for_all|last_man_standing|last_man_standing_window):/d' $CONF" ||
			die "cannot edit $CONF on $ip"
		changed+=("$ip")
	fi
done
for ip in "${changed[@]+"${changed[@]}"}"; do
	on_node "$ip" "sudo systemctl stop pacemaker corosync && sudo systemctl start pacemaker" ||
		die "cannot restart the cluster services on $ip"
	wait_members || die "cluster did not re-form after restarting $ip"
done

# Unsafe starting state: lost quorum is ignored
ok=false
for _ in $(seq 1 30); do
	if on_node "${ips[0]}" "sudo pcs property set no-quorum-policy=ignore"; then
		ok=true
		break
	fi
	sleep 2
done
$ok || die "cannot set the cluster property no-quorum-policy on ${ips[0]}"

mkdir -p "$STATE_DIR"
printf '%s\n' "${ips[@]}" >"$STATE_FILE"
chmod 644 "$STATE_FILE"
