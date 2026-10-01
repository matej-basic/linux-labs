#!/bin/bash
# clustering-03 cleanup: removes the votequorum options the solution adds,
# restores no-quorum-policy=stop and removes the state file. Safe to run
# when the lab was never started or the cluster is down.

source /opt/linux-labs/lib/load-config.sh
load_lab_config

LAB=clustering-03
CONF=/etc/corosync/corosync.conf

rm -f "/opt/linux-labs/state/$LAB"

if [ "$NODES_ENABLED" = true ] && [ "$NODE_COUNT" -ge 3 ]; then
	ips=("$(get_node_ip 1)" "$(get_node_ip 2)" "$(get_node_ip 3)")

	on_node() {
		run_on_node "$@" 2>/dev/null
	}

	# Remove the options on every node, restart only the changed ones,
	# one at a time, and wait for the cluster to re-form in between.
	changed=()
	for ip in "${ips[@]}"; do
		if on_node "$ip" "sudo grep -Eq '^[[:space:]]*(wait_for_all|last_man_standing|last_man_standing_window):[[:space:]]*[1-9]' $CONF"; then
			on_node "$ip" "sudo sed -i -E '/^[[:space:]]*(wait_for_all|last_man_standing|last_man_standing_window):/d' $CONF" || true
			changed+=("$ip")
		fi
	done
	for ip in "${changed[@]+"${changed[@]}"}"; do
		on_node "$ip" "sudo systemctl stop pacemaker corosync; sudo systemctl start pacemaker" || true
		for _ in $(seq 1 60); do
			on_node "$ip" "sudo corosync-quorumtool -s | grep -Eq '^Nodes:[[:space:]]+3\$'" && break
			sleep 2
		done
	done

	# Default policy; retry while the cluster elects a DC again
	for _ in $(seq 1 30); do
		on_node "${ips[0]}" "sudo pcs property set no-quorum-policy=stop" && break
		sleep 2
	done
fi

exit 0
