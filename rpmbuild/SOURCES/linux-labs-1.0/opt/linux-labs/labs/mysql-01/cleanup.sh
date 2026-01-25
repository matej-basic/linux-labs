#!/bin/bash
# Stop and disable MySQL/MariaDB service, remove packages and data
echo "Cleaning up MySQL/MariaDB Installation (mysql-01) lab environment..."

systemctl stop mysql mariadb mysqld 2>/dev/null
systemctl disable mysql mariadb mysqld 2>/dev/null
dnf remove -y mysql-server mariadb-server 2>/dev/null
rm -rf /var/lib/mysql/*

# End of cleanup message
echo "Cleanup completed."