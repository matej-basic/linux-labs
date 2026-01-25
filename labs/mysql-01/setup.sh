#!/bin/bash

# Reset lab state
systemctl stop mysqld mariadb > /dev/null 2>&1
dnf remove -y mysql-server mariadb-server > /dev/null 2>&1
rm -rf /var/lib/mysql/*

# Print task description
cat <<'EOF'

====================================================
LAB: MySQL - Installation and Setup (mysql-01)
====================================================

OBJECTIVE:
Install MySQL Server, start the service, and verify
basic connectivity.

REQUIREMENTS:
- Install MySQL Server package
- Start the mysqld service
- Enable mysqld to start on boot
- Set root password to: labpassword
- Verify connection to MySQL CLI
- Verify MySQL is listening on port 3306

NOTES:
- You may use any valid Linux commands
- The grading script checks only the final state
- Command history is NOT evaluated

When ready, run:
  sudo labctl grade mysql-01

====================================================

EOF

