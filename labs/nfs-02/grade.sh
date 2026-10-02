#!/bin/bash
# nfs-02 grader
source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/grading.sh
load_lab_config

PROJ=/srv/projects
DOCS=/srv/docs
ANON=3001

grade_begin nfs-02
grade_require_state nfs-02

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

# The active exports on node 1 as "<path> <client> <options>" lines.
# exportfs -v puts the client on the next line when the path is long,
# so the lines are joined first.
EXPORTS=$(on "$NODE1_IP" "exportfs -v" | awk '
	/^\// { path = $1; rest = $0; sub(/^[^ \t]+[ \t]*/, "", rest)
		if (rest == "") next }
	!/^\// { rest = $0; sub(/^[ \t]+/, "", rest) }
	path != "" {
		sub(/\/$/, "", path)
		c = rest; sub(/\(.*/, "", c)
		o = rest; sub(/^[^(]*\(/, "", o); sub(/\).*/, "", o)
		print path, c, o
	}')

# has_opts <path> <option>...: the export of <path> to node 2 has every
# option
has_opts() {
	local path="$1"
	shift
	printf '%s\n' "$EXPORTS" | awk -v p="$path" -v c="$NODE2_IP" -v want="$*" '
		$1 == p && $2 == c {
			n = split(want, w, " ")
			ok = 1
			for (i = 1; i <= n; i++) if (index("," $3 ",", "," w[i] ",") == 0) ok = 0
			if (ok) f = 1
		}
		END { exit !f }'
}

server_ok() {
	on "$NODE1_IP" "systemctl is-enabled nfs-server && systemctl is-active nfs-server"
}

# Both exports are in /etc/exports or a *.exports file in /etc/exports.d
exports_persistent() {
	local d
	for d in "$PROJ" "$DOCS"; do
		on "$NODE1_IP" "cat /etc/exports /etc/exports.d/*.exports 2>/dev/null" |
			awk -v d="$d" -v c="$NODE2_IP" '
				$1 == d || $1 == d "/" {
					for (i = 2; i <= NF; i++) if ($i == c || index($i, c "(") == 1) f = 1
				}
				END { exit !f }' || return 1
	done
}

firewall_ok() {
	on "$NODE1_IP" "firewall-cmd --query-service=nfs && firewall-cmd --permanent --query-service=nfs"
}

autofs_ok() {
	on "$NODE2_IP" "systemctl is-enabled autofs && systemctl is-active autofs"
}

# A file in /etc/auto.master.d ending in .autofs maps /shares
master_ok() {
	on "$NODE2_IP" "cat /etc/auto.master.d/*.autofs 2>/dev/null" |
		awk '$1 !~ /^#/ && ($1 == "/shares" || $1 == "/shares/") && NF >= 2 { f = 1 }
			END { exit !f }'
}

shares_autofs() {
	[ "$(on "$NODE2_IP" "findmnt -n -o FSTYPE --mountpoint /shares")" = autofs ]
}

# triggers <name> <export>: accessing /shares/<name> on node 2 mounts
# <export> of node 1 there
triggers() {
	local src fstype
	read -r src fstype < <(on "$NODE2_IP" \
		"ls /shares/$1/ >/dev/null && findmnt -n -o SOURCE,FSTYPE --mountpoint /shares/$1")
	{ [ "$src" = "$NODE1_IP:$2" ] || [ "$src" = "$NODE1_IP:$2/" ]; } &&
		{ [ "$fstype" = nfs ] || [ "$fstype" = nfs4 ]; }
}

# root on node 2 creates a file in /shares/projects; on node 1 it must
# belong to UID and GID 3001. The file is removed again.
squashed_owner() {
	local name=".nfs-02-grade-$$-$RANDOM" got rc=1
	if on "$NODE2_IP" "ls /shares/projects/ >/dev/null && mountpoint -q /shares/projects && echo $name > /shares/projects/$name"; then
		got=$(on "$NODE1_IP" "stat -c '%u:%g' $PROJ/$name")
		[ "$got" = "$ANON:$ANON" ] && rc=0
	fi
	on "$NODE1_IP" "rm -f $PROJ/$name" >/dev/null
	return "$rc"
}

# /shares/docs is mounted and root on node 2 cannot create a file in it
docs_read_only() {
	local name=".nfs-02-grade-$$-$RANDOM" rc=1
	if on "$NODE2_IP" "ls /shares/docs/ >/dev/null && mountpoint -q /shares/docs && test -r /shares/docs/manual.txt"; then
		on "$NODE2_IP" "touch /shares/docs/$name" || rc=0
		on "$NODE1_IP" "test -e $DOCS/$name" && rc=1
	fi
	on "$NODE1_IP" "rm -f $DOCS/$name" >/dev/null
	return "$rc"
}

criterion "nfs-server is enabled and running on node 1" server_ok
criterion "$PROJ is exported read-write to $NODE2_IP" has_opts "$PROJ" rw
criterion "The $PROJ export maps all users to UID and GID $ANON" \
	has_opts "$PROJ" all_squash "anonuid=$ANON" "anongid=$ANON"
criterion "$DOCS is exported read-only to $NODE2_IP" has_opts "$DOCS" ro
criterion "The $DOCS export keeps root squashing" has_opts "$DOCS" root_squash
criterion "Both exports are configured in /etc/exports or /etc/exports.d" exports_persistent
criterion "The firewall on node 1 allows the nfs service" firewall_ok
criterion "autofs is enabled and running on node 2" autofs_ok
criterion "A .autofs file in /etc/auto.master.d maps /shares" master_ok
criterion "/shares on node 2 is an autofs mount point" shares_autofs
criterion "Accessing /shares/projects mounts $NODE1_IP:$PROJ" triggers projects "$PROJ"
criterion "Accessing /shares/docs mounts $NODE1_IP:$DOCS" triggers docs "$DOCS"
criterion "Files created on node 2 in /shares/projects belong to $ANON" squashed_owner
criterion "/shares/docs on node 2 is readable and rejects writes" docs_read_only
grade_end
