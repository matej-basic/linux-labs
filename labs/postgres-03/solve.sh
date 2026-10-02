#!/bin/bash
# Reference solution for postgres-03, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /tmp/labdb_backup.sql
# solve: path /var/tmp/postgres-03.pre
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

cd /tmp

# Step 1 [sudo]
# shellcheck disable=SC2024 # the redirect must run as the invoking user
sudo -u postgres pg_dump labdb > /tmp/labdb_backup.sql
# Step 2 [sudo]
sudo -u postgres psql -c "CREATE DATABASE labdb_restore;"
# Step 3 [sudo]
sudo -u postgres psql -d labdb_restore -f /tmp/labdb_backup.sql
