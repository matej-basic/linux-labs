#!/bin/bash
# Stop and disable MySQL/MariaDB service, remove packages and data
echo "Cleaning up MySQL/MariaDB Installation (mysql-01) lab environment..."

systemctl stop mysqld mariadb > /dev/null 2>&1
systemctl disable mysqld mariadb > /dev/null 2>&1
dnf remove -y mysql-server mariadb-server > /dev/null 2>&1
rm -rf /var/lib/mysql/*

# End of cleanup message
echo "Cleanup completed."