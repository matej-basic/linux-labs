# PostgreSQL 03 Solution

Create a PostgreSQL database backup and restore it to verify data integrity.

## Commands to reach the expected state:

```bash
# Create a backup of the labdb database
sudo -u postgres pg_dump labdb > /tmp/labdb_backup.sql

# Create the restore database
sudo -u postgres psql -c "CREATE DATABASE labdb_restore;"

# Restore the backup to the new database
sudo -u postgres psql -d labdb_restore -f /tmp/labdb_backup.sql
```

## Verify:

```bash
# Check if backup file exists
ls -l /tmp/labdb_backup.sql

# Check backup file contains valid SQL
head -20 /tmp/labdb_backup.sql

# Check if labdb_restore database exists
cd /tmp && sudo -u postgres psql -l 2>/dev/null | grep labdb_restore

# Check tables in restored database
cd /tmp && sudo -u postgres psql -d labdb_restore -c "\dt" 2>/dev/null

# Compare row count in original and restored
cd /tmp && sudo -u postgres psql -t -d labdb -c "SELECT COUNT(*) FROM users;" 2>/dev/null
cd /tmp && sudo -u postgres psql -t -d labdb_restore -c "SELECT COUNT(*) FROM users;" 2>/dev/null

# Compare data in both databases
cd /tmp && sudo -u postgres psql -d labdb -c "SELECT * FROM users;" 2>/dev/null
cd /tmp && sudo -u postgres psql -d labdb_restore -c "SELECT * FROM users;" 2>/dev/null

# Run the grading script
sudo labctl grade postgres-03
```

