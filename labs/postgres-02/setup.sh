#!/bin/bash

# Reset lab state
sudo -u postgres psql -d postgres -c "DROP DATABASE IF EXISTS labdb;" > /dev/null 2>&1
sudo -u postgres psql -d postgres -c "DROP ROLE IF EXISTS labuser;" > /dev/null 2>&1

# Print task description
cat <<'EOF'

====================================================
LAB: PostgreSQL - Database and Role Management (postgres-02)
====================================================

OBJECTIVE:
Create a PostgreSQL database and role with specific
privileges for application access.

REQUIREMENTS:
- PostgreSQL Server must be installed and running
- Configure pg_hba.conf to allow password authentication
- Create role: labuser with password: userpass123
- Create database: labdb
- Grant CONNECT privilege on labdb to labuser
- Grant USAGE on public schema to labuser
- Create a sample table: users (id, name, email)
- Grant SELECT, INSERT, UPDATE, DELETE on users
- Insert at least 2 sample records
- Verify user can connect and access data

NOTES:
- User should have access to labdb only
- User should NOT have administrative privileges
- The grading script checks only the final state
- Command history is NOT evaluated

When ready, run:
  sudo labctl grade postgres-02

====================================================

EOF

