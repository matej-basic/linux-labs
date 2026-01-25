#!/bin/bash

# Reset lab state
mysql -u root -plabpassword -e "DROP DATABASE IF EXISTS labdb_restore;" 2>/dev/null
rm -f /tmp/labdb_backup.sql

# Print task description
cat <<'EOF'

====================================================
LAB: MySQL - Backup and Restore (mysql-03)
====================================================

OBJECTIVE:
Create a MySQL database backup using mysqldump and
restore from backup to verify data integrity.

REQUIREMENTS:
- MySQL Server must be installed and running
- Database labdb must exist with sample data
- Create a backup: /tmp/labdb_backup.sql
- Create restore database: labdb_restore
- Restore backup to labdb_restore
- Verify all tables and data are restored
- Verify row count matches original

NOTES:
- Use mysqldump for backup creation
- Use mysql command to restore from backup
- Backup file must be readable and valid SQL
- The grading script checks only the final state
- Command history is NOT evaluated

When ready, run:
  sudo labctl grade mysql-03

====================================================

EOF

