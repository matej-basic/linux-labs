#!/bin/bash
# time-01 grader
#
# The configuration checks read the effective chrony configuration as
# chronyd -p prints it (chrony.conf with every included file), so the
# result does not depend on the file layout. Access and sources are the
# running state of chronyd (chronyc).
source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/grading.sh
load_lab_config

grade_begin time-01
grade_require_state time-01

[ "$NODES_ENABLED" = "true" ] || grade_abort "Multi-node labs are enabled in the configuration"
[ "$NODE_COUNT" -ge 2 ] 2>/dev/null || grade_abort "The configuration defines at least 2 nodes"

NODE1_IP=$(get_node_ip 1)
NODE2_IP=$(get_node_ip 2)

for ip in "$NODE1_IP" "$NODE2_IP"; do
	test_node_connectivity "$ip" >/dev/null 2>&1 || grade_abort "Nodes 1 and 2 are reachable over SSH"
done

# on <ip> <command>: run a command as root on a node
on() {
	run_on_node "$1" "sudo -n sh -c $(printf '%q' "$2")" </dev/null 2>/dev/null
}

CONF1=$(on "$NODE1_IP" "chronyd -p")
CONF2=$(on "$NODE2_IP" "chronyd -p")

chronyd_ok() {
	on "$1" "systemctl is-enabled chronyd && systemctl is-active chronyd"
}

# Node 1 lets node 2 query it, in the running chronyd and in the
# configuration (a runtime-only allow is lost at the next restart)
allow_ok() {
	printf '%s\n' "$CONF1" | grep -qE '^allow([[:space:]]|$)' || return 1
	on "$NODE1_IP" "chronyc accheck $NODE2_IP" | grep -q '^208 '
}

# A local directive with stratum 10 (the default when no stratum is given)
local_ok() {
	printf '%s\n' "$CONF1" | awk '
		$1 == "local" {
			s = 10
			for (i = 2; i < NF; i++) if ($i == "stratum") s = $(i + 1)
			if (s == 10) f = 1
		}
		END { exit !f }'
}

firewall_ok() {
	on "$NODE1_IP" "firewall-cmd --query-service=ntp && firewall-cmd --permanent --query-service=ntp"
}

# Exactly one source directive on node 2: server <node 1> with iburst
config2_ok() {
	printf '%s\n' "$CONF2" | awk -v ip="$NODE1_IP" '
		$1 == "server" || $1 == "pool" || $1 == "peer" || $1 == "refclock" {
			n++
			if ($1 == "server" && $2 == ip)
				for (i = 3; i <= NF; i++) if ($i == "iburst") ok = 1
		}
		END { exit !(n == 1 && ok) }'
}

# chronyc lists node 1 and no other source on node 2
only_source() {
	on "$NODE2_IP" "chronyc -n sources" | awk -v ip="$NODE1_IP" '
		/^[\^=#][*+?x~ -] / { n++; if ($2 == ip) f = 1 }
		END { exit !(n == 1 && f) }'
}

# Node 2 has selected node 1 (^*). A fresh chronyd needs a few samples
# first, so wait up to 60 seconds while node 1 is a listed source.
synced() {
	run_on_node "$NODE2_IP" "sudo -n bash -s" 2>/dev/null <<EOF
for i in \$(seq 1 30); do
	out=\$(chronyc -n sources 2>/dev/null)
	printf '%s\n' "\$out" | grep -q '^\^\* $NODE1_IP ' && exit 0
	printf '%s\n' "\$out" | grep -q '^\^. $NODE1_IP ' || exit 1
	sleep 2
done
exit 1
EOF
}

timezone_ok() {
	[ "$(on "$NODE2_IP" "timedatectl show -p Timezone --value")" = Europe/Zagreb ]
}

criterion "chronyd is enabled and running on node 1" chronyd_ok "$NODE1_IP"
criterion "Node 1 allows NTP clients from $NODE2_IP" allow_ok
criterion "Node 1 has a local reference at stratum 10" local_ok
criterion "The firewall on node 1 allows the ntp service" firewall_ok
criterion "chronyd is enabled and running on node 2" chronyd_ok "$NODE2_IP"
criterion "Node 2 is configured with server $NODE1_IP iburst only" config2_ok
criterion "Node 1 is the only NTP source of node 2" only_source
criterion "Node 2 is synchronised to node 1" synced
criterion "The time zone of node 2 is Europe/Zagreb" timezone_ok
grade_end
