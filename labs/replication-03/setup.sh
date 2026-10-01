#!/bin/bash
# replication-03 setup: puts the three nodes into the clean starting state
# (mysql-server installed and running with its packaged configuration, no
# replication, no replication account, MySQL port closed). Prints nothing
# on success.
# No "set -u": load-config.sh reads variables that may be unset.
set -e

source /opt/linux-labs/lib/load-config.sh
load_lab_config

STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/replication-03"

if [ "$NODES_ENABLED" != "true" ]; then
	echo "replication-03 needs multi-node labs: run 'sudo labctl configure interactive' and enable them" >&2
	exit 1
fi
if [ "$NODE_COUNT" -lt 3 ] 2>/dev/null; then
	echo "replication-03 needs 3 nodes, NODE_COUNT is $NODE_COUNT: run 'sudo labctl configure set NODE_COUNT 3'" >&2
	exit 1
fi

for n in 1 2 3; do
	ip=$(get_node_ip "$n")
	if ! test_node_connectivity "$ip" >/dev/null; then
		echo "Cannot reach node $n ($ip) over SSH as $SSH_USER" >&2
		exit 1
	fi
done

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Remote reset, run as root on every node. The marker file records that
# the lab installed mysql-server, so that cleanup.sh removes it again. The
# backup holds the packaged mysql-server.cnf, which the reset restores.
cat > "$tmp/node.sh" <<'REMOTE'
cnf=/etc/my.cnf.d/mysql-server.cnf
bak=/var/tmp/replication-03.mysql-server.cnf
marker=/var/tmp/replication-03.installed

if ! rpm -q mysql-server >/dev/null 2>&1; then
	dnf -y install mysql-server </dev/null >/dev/null || exit 1
	touch "$marker"
fi

if [ -f "$bak" ]; then
	cp -p "$bak" "$cnf"
elif [ -f "$cnf" ]; then
	cp -p "$cnf" "$bak"
fi
rm -f /etc/my.cnf.d/replication.cnf

if systemctl is-active --quiet mysqld; then
	for q in "STOP REPLICA" "RESET REPLICA ALL" "DROP USER IF EXISTS 'repl'@'%'"; do
		printf '%s;\n' "$q" | mysql -u root >/dev/null 2>&1 || true
	done
fi

firewall-cmd --permanent --remove-service=mysql >/dev/null 2>&1
firewall-cmd --permanent --remove-port=3306/tcp >/dev/null 2>&1
firewall-cmd --reload >/dev/null 2>&1

systemctl enable mysqld </dev/null >/dev/null 2>&1 || exit 1
systemctl restart mysqld </dev/null || exit 1
for _ in $(seq 30); do
	echo "SELECT 1;" | mysql -u root >/dev/null 2>&1 && exit 0
	sleep 1
done
echo "mysqld does not answer on the local socket" >&2
exit 1
REMOTE

# All three nodes in parallel; dnf may take a while on a fresh node
pids=""
for n in 1 2 3; do
	ip=$(get_node_ip "$n")
	run_on_node "$ip" "sudo bash -s" < "$tmp/node.sh" > /dev/null 2> "$tmp/err.$n" &
	pids="$pids $!"
done

rc=0
n=0
for pid in $pids; do
	n=$((n + 1))
	if ! wait "$pid"; then
		echo "Preparing node $n ($(get_node_ip "$n")) failed:" >&2
		cat "$tmp/err.$n" >&2
		rc=1
	fi
done
[ "$rc" -eq 0 ] || exit 1

mkdir -p "$STATE_DIR"
get_all_node_ips | awk '{ print $1, $2, $3 }' > "$STATE_FILE"
chmod 644 "$STATE_FILE"
