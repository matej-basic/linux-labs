#!/bin/bash

# Reset lab state
systemctl stop postgresql postgresql-* > /dev/null 2>&1
systemctl disable postgresql postgresql-* > /dev/null 2>&1
dnf remove -y postgresql postgresql-server postgresql-contrib > /dev/null 2>&1
rm -rf /var/lib/pgsql/data

# Print task description
cat <<'EOF'

====================================================
LAB: PostgreSQL - Installation and Setup (postgres-01)
====================================================

OBJECTIVE:
Install PostgreSQL Server, start the service, and
verify basic connectivity.

REQUIREMENTS:
- Install PostgreSQL Server package
- Initialize the database cluster (initdb)
- Start the postgresql service
- Enable postgresql to start on boot
- Verify connection to PostgreSQL CLI
- Verify PostgreSQL is listening on port 5432

NOTES:
- You may use any valid Linux commands
- The grading script checks only the final state
- Command history is NOT evaluated

When ready, run:
  sudo labctl grade postgres-01

====================================================

EOF

