#!/bin/bash
# Reference solution for postgres-01, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: package postgresql-server
# solve: path /var/lib/pgsql
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
rpm -q postgresql-server >/dev/null || dnf -y install postgresql-server

# Step 2 [sudo]
postgresql-setup --initdb

# Step 3 [sudo]
systemctl enable --now postgresql

# Step 4 [sudo]
ss -tlnp | grep -q 5432
cd /tmp
runuser -u postgres -- psql -d postgres -c 'SELECT version();'
