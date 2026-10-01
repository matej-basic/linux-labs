# postgres-03: PostgreSQL backup and restore

## Solution

1. [sudo] Create a plain-text backup of labdb. The redirect is done by
   your own shell, so the file belongs to you and the postgres user
   can still read it:

   ```bash
   cd /tmp
   sudo -u postgres pg_dump labdb > /tmp/labdb_backup.sql
   ```

2. [sudo] Create the restore database:

   ```bash
   sudo -u postgres psql -c "CREATE DATABASE labdb_restore;"
   ```

3. [sudo] Restore the backup into the new database:

   ```bash
   sudo -u postgres psql -d labdb_restore -f /tmp/labdb_backup.sql
   ```

## Verification

```bash
head -20 /tmp/labdb_backup.sql
sudo -u postgres psql -d labdb_restore -c "\dt"
sudo -u postgres psql -d labdb -c "SELECT * FROM users;"
sudo -u postgres psql -d labdb_restore -c "SELECT * FROM users;"
labctl grade postgres-03
```

## Explanation

pg_dump without options writes a plain-text SQL script: CREATE TABLE
statements and the rows as a COPY block. psql replays that script, so
the new database gets the same tables and rows. The dump does not
contain CREATE DATABASE, which is why the empty database must exist
before the restore.

Commands run as the postgres account through sudo because the server
uses peer authentication for local connections. Run them from a
directory the postgres user can enter (such as /tmp), otherwise sudo
prints a harmless warning. A dump in custom or tar format (pg_dump -Fc
or -Ft) is not plain SQL and fails the backup criteria.
