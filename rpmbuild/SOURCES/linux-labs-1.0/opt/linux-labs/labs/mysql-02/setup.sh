#!/bin/bash

# Reset lab state
mysql -u root -plabpassword -e "DROP DATABASE IF EXISTS labdb;" 2>/dev/null
mysql -u root -plabpassword -e "DROP USER IF EXISTS 'labuser'@'localhost';" 2>/dev/null

# Print task description
cat <<'EOF'

====================================================
LAB: MySQL - Database and User Management (mysql-02)
====================================================

OBJECTIVE:
Create a MySQL database and user with specific
privileges for application access.

REQUIREMENTS:
- MySQL Server must be installed and running
- Root password must be set to: labpassword
- Create database: labdb
- Create user: labuser
- Set user password to: userpass123
- Grant SELECT, INSERT, UPDATE, DELETE on labdb.*
- Create a sample table: users (id, name, email)
- Insert at least 2 sample records
- Verify user can connect and access data

NOTES:
- User should have access to labdb only
- User should NOT have administrative privileges
- The grading script checks only the final state
- Command history is NOT evaluated

When ready, run:
  sudo labctl grade mysql-02

====================================================

EOF

