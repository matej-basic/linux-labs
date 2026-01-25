#!/bin/bash
# Drop restore database and remove backup file
echo "Cleaning up PostgreSQL Backup and Restore (postgres-03) lab environment..."

sudo -u postgres psql -d postgres -c "DROP DATABASE IF EXISTS labdb_restore;" > /dev/null 2>&1
rm -f /tmp/labdb_backup.sql

# End of cleanup message
echo "Cleanup completed."

