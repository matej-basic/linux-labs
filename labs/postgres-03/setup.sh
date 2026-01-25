#!/bin/bash

# Reset lab state
sudo -u postgres psql -d postgres -c "DROP DATABASE IF EXISTS labdb_restore;" > /dev/null 2>&1
rm -f /tmp/labdb_backup.sql

# Print task description
cat <<'EOF'

====================================================
LAB: PostgreSQL - Backup and Restore (postgres-03)
====================================================

OBJECTIVE:
Create a PostgreSQL database backup using pg_dump
and restore from backup to verify data integrity.

REQUIREMENTS:
- PostgreSQL Server must be installed and running
- Password authentication must be configured
- Database labdb must exist with sample data
- Create a backup: /tmp/labdb_backup.sql
- Create restore database: labdb_restore
- Restore backup to labdb_restore
- Verify all tables and data are restored
- Verify row count matches original

NOTES:
- Use pg_dump for backup creation
- Use psql to restore from backup
- Backup file must be readable and valid SQL
- The grading script checks only the final state
- Command history is NOT evaluated

When ready, run:
  sudo labctl grade postgres-03

====================================================

EOF

