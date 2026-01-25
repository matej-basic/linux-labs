#!/bin/bash
# Drop restore database and remove backup file
echo "Cleaning up MySQL Backup and Restore (mysql-03) lab environment..."

mysql -u root -plabpassword -e "DROP DATABASE IF EXISTS labdb_restore;" 2>/dev/null
rm -f /tmp/labdb_backup.sql

# End of cleanup message
echo "Cleanup completed."

