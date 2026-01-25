#!/bin/bash
# Stop and disable PostgreSQL service, remove packages and data
echo "Cleaning up PostgreSQL Installation (postgres-01) lab environment..."

systemctl stop postgresql > /dev/null 2>&1
systemctl disable postgresql > /dev/null 2>&1
dnf remove -y postgresql-server postgresql-contrib > /dev/null 2>&1
rm -rf /var/lib/pgsql/data

# End of cleanup message
echo "Cleanup completed."

