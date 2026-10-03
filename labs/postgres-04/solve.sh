#!/bin/bash
# Reference solution for postgres-04, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: package postgresql-server
# solve: package policycoreutils-python-utils
# solve: path /var/lib/pgsql
# solve: path /var/tmp/postgres-04.bak
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

DATA=/var/lib/pgsql/data
LOG="$DATA/log/postgresql-$(date +%a).log"

# Journal and server log since this point
since=$(date '+%Y-%m-%d %H:%M:%S')
sleep 1

# Step 1 [sudo]: the data directory has group or world access
if systemctl is-active --quiet postgresql; then exit 1; fi
systemctl status postgresql >/dev/null 2>&1 || true
journalctl -u postgresql -n 20 --no-pager |
	grep -E 'data directory .* has (group or world access|invalid permissions)' >/dev/null

# Step 2 [sudo]
ls -ld "$DATA"
chmod 0700 "$DATA"
if systemctl start postgresql; then exit 1; fi

# Step 3 [sudo]: the bind is denied, in the journal (Rocky 8) or the
# server log (Rocky 9)
{
	journalctl -u postgresql --since "$since" --no-pager
	cat "$LOG"
} | grep 'could not bind IPv4 address "127.0.0.1": Permission denied' >/dev/null
grep -n '^port' "$DATA/postgresql.conf" | grep 5433 >/dev/null

# Step 4 [sudo]. ausearch reads standard input when it is not a
# terminal, as under test-lab.sh, so --input-logs makes it read the log.
ausearch --input-logs -m AVC -ts recent | grep name_bind >/dev/null
semanage port -l | grep postgresql

# Step 5 [sudo]
semanage port -a -t postgresql_port_t -p tcp 5433
if systemctl start postgresql; then exit 1; fi

# Step 6 [sudo]
tail -n 5 "$LOG" | grep 'invalid authentication method "scram-sha256"' >/dev/null

# Step 7 [sudo]
grep -n scram "$DATA/pg_hba.conf"
sed -i 's/scram-sha256$/scram-sha-256/' "$DATA/pg_hba.conf"
systemctl enable --now postgresql
ss -tlnp | grep 5433

# Step 8 [user]
run_as_student <<'STEPS'
test "$(PGPASSWORD=Stock-2026 psql -X -qAt -h 127.0.0.1 -p 5433 -U labapp \
	-d labdb -c 'SELECT count(*) FROM inventory')" = 12
STEPS
