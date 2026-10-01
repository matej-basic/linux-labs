#!/bin/bash
# replication-02 setup: PostgreSQL installed on node 1 and node 2, a
# running standalone cluster on node 1, and an empty data directory on
# node 2. Prints nothing on success.
#
# Node state lives in /var/lib/pgsql/lab-replication-02 on each node:
# node 1 keeps its original configuration files there, node 2 keeps
# its original data directory (data.orig). cleanup.sh restores both.
set -e

STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/replication-02"

# shellcheck source=/dev/null
source /opt/linux-labs/lib/load-config.sh
load_lab_config

if [[ "$NODES_ENABLED" != "true" ]]; then
	echo "Error: multi-node labs are not enabled (run: sudo labctl configure interactive)." >&2
	exit 1
fi
if [[ "$NODE_COUNT" -lt 2 ]]; then
	echo "Error: this lab needs at least 2 nodes (NODE_COUNT is $NODE_COUNT)." >&2
	exit 1
fi

PRIMARY_IP=$(get_node_ip 1)
STANDBY_IP=$(get_node_ip 2)

for ip in "$PRIMARY_IP" "$STANDBY_IP"; do
	if ! test_node_connectivity "$ip" >/dev/null; then
		echo "Error: node $ip is not reachable over SSH (user $SSH_USER, key $SSH_KEY_PATH)." >&2
		exit 1
	fi
done

# Node 1: install PostgreSQL, make sure a cluster exists, save the original
# configuration once, then return to it (also after an earlier attempt),
# remove lab leftovers and restart.
if ! out=$(run_on_node "$PRIMARY_IP" "sudo -n bash -s" 2>&1 <<'EOF_PRIMARY'
set -e
B=/var/lib/pgsql/lab-replication-02
D=/var/lib/pgsql/data
FILES="postgresql.conf postgresql.auto.conf pg_hba.conf"

rpm -q postgresql-server >/dev/null 2>&1 || dnf -y -q install postgresql-server
[ -f "$D/PG_VERSION" ] || postgresql-setup --initdb

if [ -d "$B" ]; then
	for f in $FILES; do
		if [ -f "$B/$f" ]; then cp -p "$B/$f" "$D/$f"; else rm -f "$D/$f"; fi
	done
else
	mkdir -p "$B"
	if systemctl is-enabled --quiet postgresql; then echo 1 >"$B/was_enabled"; fi
	for f in $FILES; do
		if [ -f "$D/$f" ]; then cp -p "$D/$f" "$B/$f"; fi
	done
fi
rm -rf /var/lib/pgsql/wal_archive

if systemctl is-active --quiet firewalld; then
	firewall-cmd -q --permanent --remove-service=postgresql || true
	firewall-cmd -q --remove-service=postgresql || true
	firewall-cmd -q --permanent --remove-port=5432/tcp || true
	firewall-cmd -q --remove-port=5432/tcp || true
fi

systemctl restart postgresql
# Wait until the server accepts connections
for i in $(seq 1 30); do
	(cd /tmp && sudo -u postgres psql -X -Atq -c 'SELECT 1' >/dev/null 2>&1) && break
	sleep 1
done
cd /tmp
sudo -u postgres psql -X -q -c 'DROP ROLE IF EXISTS repl'
sudo -u postgres psql -X -Atq -c "SELECT format('DROP TABLE %I', tablename) FROM pg_tables WHERE schemaname = 'public' AND tablename ~ '^(repl_test_.*|replication_test)$'" | sudo -u postgres psql -X -q
EOF_PRIMARY
); then
	printf '%s\n' "$out" >&2
	echo "Error: preparing PostgreSQL on node 1 ($PRIMARY_IP) failed." >&2
	exit 1
fi

# Node 2: install PostgreSQL, keep the original data directory aside once,
# then leave an empty data directory behind.
if ! out=$(run_on_node "$STANDBY_IP" "sudo -n bash -s" 2>&1 <<'EOF_STANDBY'
set -e
B=/var/lib/pgsql/lab-replication-02
D=/var/lib/pgsql/data

rpm -q postgresql-server >/dev/null 2>&1 || dnf -y -q install postgresql-server

if [ ! -d "$B" ]; then
	mkdir -p "$B"
	if systemctl is-active --quiet postgresql; then echo 1 >"$B/was_active"; fi
	if systemctl is-enabled --quiet postgresql; then echo 1 >"$B/was_enabled"; fi
	systemctl stop postgresql
	if [ -d "$D" ]; then mv "$D" "$B/data.orig"; fi
else
	systemctl stop postgresql
fi
rm -rf "$D"
install -d -o postgres -g postgres -m 700 "$D"
restorecon -R "$D" 2>/dev/null || true
if [ -f /var/lib/pgsql/.pgpass ]; then
	sed -i '/:repl:replpassword$/d' /var/lib/pgsql/.pgpass
fi
EOF_STANDBY
); then
	printf '%s\n' "$out" >&2
	echo "Error: preparing PostgreSQL on node 2 ($STANDBY_IP) failed." >&2
	exit 1
fi

mkdir -p "$STATE_DIR"
printf 'primary=%s\nstandby=%s\n' "$PRIMARY_IP" "$STANDBY_IP" >"$STATE_FILE"
chmod 644 "$STATE_FILE"
