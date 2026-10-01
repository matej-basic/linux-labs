#!/bin/bash
# Reference solution for replication-02, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
# The work happens on node 1 and node 2 over SSH (run_on_node), so there
# is nothing on the workstation to declare.
#
# solve: none
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"
# shellcheck source=/dev/null
source /opt/linux-labs/lib/load-config.sh
load_lab_config

N1=$(get_node_ip 1)
N2=$(get_node_ip 2)

# Steps 2 to 7 on node 1
run_on_node "$N1" "N1=$N1 N2=$N2 bash -s" <<'STEPS'
set -euo pipefail
sudo install -d -o postgres -g postgres -m 700 /var/lib/pgsql/wal_archive

cd /tmp
ARCH=/var/lib/pgsql/wal_archive
sudo -u postgres psql \
     -c "ALTER SYSTEM SET listen_addresses TO '*'" \
     -c "ALTER SYSTEM SET wal_level TO replica" \
     -c "ALTER SYSTEM SET max_wal_senders TO 5" \
     -c "ALTER SYSTEM SET archive_mode TO on" \
     -c "ALTER SYSTEM SET archive_command TO 'cp %p $ARCH/%f'"

HBA=/var/lib/pgsql/data/pg_hba.conf
echo "host replication repl $N2/32 md5" | sudo tee -a $HBA

if systemctl is-active --quiet firewalld; then
	sudo firewall-cmd --permanent --add-service=postgresql
	sudo firewall-cmd --reload
fi

sudo systemctl enable postgresql
sudo systemctl restart postgresql
for i in $(seq 1 30); do
	sudo -u postgres psql -c 'SELECT 1' >/dev/null 2>&1 && break
	sleep 1
done

sudo -u postgres psql \
     -c "CREATE ROLE repl LOGIN REPLICATION PASSWORD 'replpassword'"
STEPS

# Steps 8 to 11 on node 2
run_on_node "$N2" "N1=$N1 N2=$N2 bash -s" <<'STEPS'
set -euo pipefail
sudo systemctl stop postgresql
test -z "$(sudo ls -A /var/lib/pgsql/data)"

PGPASS=/var/lib/pgsql/.pgpass
echo "$N1:5432:*:repl:replpassword" | \
     sudo -u postgres tee $PGPASS
sudo chmod 600 $PGPASS

cd /tmp
sudo -u postgres pg_basebackup -h "$N1" -U repl -w -P -R \
     -X stream -D /var/lib/pgsql/data

sudo systemctl enable --now postgresql
STEPS
