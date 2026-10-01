#!/bin/bash
# Reference solution for mysql-03, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /tmp/labdb_backup.sql
# solve: path /var/lib/mysql/labdb_restore
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Steps 1 to 3 [user]
run_as_student <<'STEPS'
mysqldump -u root -plabpassword labdb > /tmp/labdb_backup.sql
mysql -u root -plabpassword -e "CREATE DATABASE labdb_restore;"
mysql -u root -plabpassword labdb_restore < /tmp/labdb_backup.sql
STEPS
