# MySQL 03 Solution

Create a MySQL database backup and restore it to verify data integrity.

## Commands to reach the expected state:

```bash
# Create a backup of the labdb database
sudo mysqldump -u root -plabpassword labdb > /tmp/labdb_backup.sql

# Create the restore database
sudo mysql -u root -plabpassword -e "CREATE DATABASE labdb_restore;"

# Restore the backup to the new database
sudo mysql -u root -plabpassword labdb_restore < /tmp/labdb_backup.sql
```

## Verify:

```bash
# Check if backup file exists
ls -l /tmp/labdb_backup.sql

# Check backup file contains valid SQL
head -20 /tmp/labdb_backup.sql

# Check if labdb_restore database exists
mysql -u root -plabpassword -e "SHOW DATABASES;" | grep labdb_restore

# Check tables in restored database
mysql -u root -plabpassword labdb_restore -e "SHOW TABLES;"

# Compare row count in original and restored
mysql -u root -plabpassword labdb -e "SELECT COUNT(*) FROM users;"
mysql -u root -plabpassword labdb_restore -e "SELECT COUNT(*) FROM users;"

# Compare data in both databases
mysql -u root -plabpassword labdb -e "SELECT * FROM users;"
mysql -u root -plabpassword labdb_restore -e "SELECT * FROM users;"

# Run the grading script
sudo labctl grade mysql-03
```

