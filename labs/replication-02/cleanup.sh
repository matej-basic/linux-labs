#!/bin/bash
# replication-02 cleanup: undoes setup.sh and the solution on both nodes.
# Node 1 gets its original configuration back and loses the repl role, the
# WAL archive and the firewall rule. Node 2 gets its original data
# directory back (or an empty one). Nodes that were never prepared by
# setup.sh (no /var/lib/pgsql/lab-replication-02) are left alone.
# PostgreSQL packages stay installed.

# shellcheck source=/dev/null
source /opt/linux-labs/lib/load-config.sh
load_lab_config

rm -f /opt/linux-labs/state/replication-02

if [[ "$NODES_ENABLED" != "true" || "$NODE_COUNT" -lt 2 ]]; then
	exit 0
fi

PRIMARY_IP=$(get_node_ip 1)
STANDBY_IP=$(get_node_ip 2)
rc=0

# Node 2 first, so that nothing replicates from node 1 while it is reset
run_on_node "$STANDBY_IP" "bash -s" >/dev/null <<'EOF_STANDBY' || rc=1
B=/var/lib/pgsql/lab-replication-02
D=/var/lib/pgsql/data

[ -d "$B" ] || exit 0
systemctl stop postgresql || true
rm -rf "$D"
if [ -d "$B/data.orig" ]; then
	mv "$B/data.orig" "$D"
else
	install -d -o postgres -g postgres -m 700 "$D"
fi
restorecon -R "$D" 2>/dev/null || true
if [ -f /var/lib/pgsql/.pgpass ]; then
	sed -i '/:repl:replpassword$/d' /var/lib/pgsql/.pgpass
	[ -s /var/lib/pgsql/.pgpass ] || rm -f /var/lib/pgsql/.pgpass
fi
if [ -f "$B/was_active" ]; then systemctl start postgresql || true; fi
rm -rf "$B"
exit 0
EOF_STANDBY

run_on_node "$PRIMARY_IP" "bash -s" >/dev/null <<'EOF_PRIMARY' || rc=1
B=/var/lib/pgsql/lab-replication-02
D=/var/lib/pgsql/data
FILES="postgresql.conf postgresql.auto.conf pg_hba.conf"

[ -d "$B" ] || exit 0

# Drop the lab objects while the server is up
systemctl start postgresql || true
for i in $(seq 1 30); do
	(cd /tmp && sudo -u postgres psql -X -Atq -c 'SELECT 1' >/dev/null 2>&1) && break
	sleep 1
done
cd /tmp
sudo -u postgres psql -X -Atq -c "SELECT format('DROP TABLE %I', tablename) FROM pg_tables WHERE schemaname = 'public' AND tablename ~ '^(repl_test_.*|replication_test)$'" 2>/dev/null | sudo -u postgres psql -X -q 2>/dev/null
sudo -u postgres psql -X -q -c 'DROP ROLE IF EXISTS repl' 2>/dev/null

for f in $FILES; do
	if [ -f "$B/$f" ]; then cp -p "$B/$f" "$D/$f"; else rm -f "$D/$f"; fi
done
rm -rf /var/lib/pgsql/wal_archive
if systemctl is-active --quiet firewalld; then
	firewall-cmd -q --permanent --remove-service=postgresql || true
	firewall-cmd -q --remove-service=postgresql || true
	firewall-cmd -q --permanent --remove-port=5432/tcp || true
	firewall-cmd -q --remove-port=5432/tcp || true
fi
systemctl restart postgresql || true
rm -rf "$B"
exit 0
EOF_PRIMARY

exit "$rc"
