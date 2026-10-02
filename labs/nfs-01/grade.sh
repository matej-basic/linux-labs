#!/bin/bash
# nfs-01 grader
source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/grading.sh
load_lab_config

DIR=/srv/nfsshare
MP=/mnt/nfsshare

grade_begin nfs-01
grade_require_state nfs-01

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

# The active exports of the lab directory on node 1, one
# "<client> <options>" line each. exportfs -v puts the client on the
# next line when the path is long, so the lines are joined first.
EXPORTS=$(on "$NODE1_IP" "exportfs -v" | awk -v d="$DIR" '
	/^\// { path = $1; rest = $0; sub(/^[^ \t]+[ \t]*/, "", rest)
		if (rest == "") next }
	!/^\// { rest = $0; sub(/^[ \t]+/, "", rest) }
	path == d || path == d "/" {
		c = rest; sub(/\(.*/, "", c)
		o = rest; sub(/^[^(]*\(/, "", o); sub(/\).*/, "", o)
		print c, o
	}')

server_ok() {
	on "$NODE1_IP" "systemctl is-enabled nfs-server && systemctl is-active nfs-server"
}

exported_rw_to_node2() {
	printf '%s\n' "$EXPORTS" | awk -v c="$NODE2_IP" '
		$1 == c && ("," $2 ",") ~ /,rw,/ { f = 1 } END { exit !f }'
}

only_node2() {
	[ -n "$EXPORTS" ] || return 1
	printf '%s\n' "$EXPORTS" | awk -v c="$NODE2_IP" '
		$1 != c { bad = 1 } END { exit bad }'
}

root_squash_on() {
	printf '%s\n' "$EXPORTS" | awk -v c="$NODE2_IP" '
		$1 == c && ("," $2 ",") ~ /,root_squash,/ { f = 1 } END { exit !f }'
}

# The export is in /etc/exports or a *.exports file in /etc/exports.d
export_persistent() {
	on "$NODE1_IP" "cat /etc/exports /etc/exports.d/*.exports 2>/dev/null" |
		awk -v d="$DIR" -v c="$NODE2_IP" '
			$1 == d || $1 == d "/" {
				for (i = 2; i <= NF; i++) if ($i == c || index($i, c "(") == 1) f = 1
			}
			END { exit !f }'
}

firewall_ok() {
	on "$NODE1_IP" "firewall-cmd --query-service=nfs && firewall-cmd --permanent --query-service=nfs"
}

fstab_ok() {
	on "$NODE2_IP" "cat /etc/fstab" | awk -v s="$NODE1_IP:$DIR" -v m="$MP" '
		$1 !~ /^#/ && ($1 == s || $1 == s "/") && ($2 == m || $2 == m "/") &&
			($3 == "nfs" || $3 == "nfs4") { f = 1 }
		END { exit !f }'
}

mounted_ok() {
	local src fstype
	read -r src fstype < <(on "$NODE2_IP" "findmnt -n -o SOURCE,FSTYPE --mountpoint $MP")
	{ [ "$src" = "$NODE1_IP:$DIR" ] || [ "$src" = "$NODE1_IP:$DIR/" ]; } &&
		{ [ "$fstype" = nfs ] || [ "$fstype" = nfs4 ]; }
}

# root on node 2 writes a file into the mount; it must show up with the
# same content in the directory on node 1. The file is removed again.
write_appears_on_node1() {
	local name=".nfs-01-grade-$$-$RANDOM" got rc=1
	if on "$NODE2_IP" "mountpoint -q $MP && echo $name > $MP/$name"; then
		got=$(on "$NODE1_IP" "cat $DIR/$name")
		[ "$got" = "$name" ] && rc=0
	fi
	on "$NODE1_IP" "rm -f $DIR/$name" >/dev/null
	return "$rc"
}

criterion "nfs-server is enabled and running on node 1" server_ok
criterion "$DIR is exported read-write to $NODE2_IP" exported_rw_to_node2
criterion "$DIR is exported to no other client" only_node2
criterion "The export to $NODE2_IP keeps root squashing" root_squash_on
criterion "The export is configured in /etc/exports or /etc/exports.d" export_persistent
criterion "The firewall on node 1 allows the nfs service" firewall_ok
criterion "/etc/fstab on node 2 has the NFS entry for $MP" fstab_ok
criterion "$NODE1_IP:$DIR is mounted at $MP on node 2" mounted_ok
criterion "A file written by root on node 2 appears on node 1" write_appears_on_node1
grade_end
