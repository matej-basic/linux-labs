#!/bin/bash
# Reference solution for mysql-01, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: package mysql-server
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
dnf install -y mysql-server

# Step 2 [sudo]
systemctl enable --now mysqld

# Step 3 [sudo]
mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'labpassword';"
