# mysql-03: MySQL backup and restore

## Hints

1. A logical backup is a text file of SQL statements that recreates the
   tables and rows. MySQL ships a client program for exactly this, and
   a restore feeds such a file back to the server.
2. Read man mysqldump for the backup. The restore uses the ordinary
   mysql client, and the target database must exist before the load.
3. Name only labdb on the mysqldump command line and redirect the
   output to the file. Skip the --databases option: it adds a USE
   statement that sends the restore back into labdb.
4. For the restore, give mysql the name labdb_restore as its default
   database and read the backup file on standard input.

## Solution

1. [user] Dump the database labdb into a file:

   ```bash
   mysqldump -u root -plabpassword labdb > /tmp/labdb_backup.sql
   ```

2. [user] Create the empty restore database:

   ```bash
   mysql -u root -plabpassword -e "CREATE DATABASE labdb_restore;"
   ```

3. [user] Load the dump into the new database:

   ```bash
   mysql -u root -plabpassword labdb_restore < /tmp/labdb_backup.sql
   ```

## Verification

```bash
mysql -u root -plabpassword labdb_restore -e "SHOW TABLES;"
mysql -u root -plabpassword -e "SELECT COUNT(*) FROM labdb.users;"
mysql -u root -plabpassword \
  -e "SELECT COUNT(*) FROM labdb_restore.users;"
labctl grade mysql-03
```

## Explanation

mysqldump writes the table definitions and the rows of one database as
SQL statements. Because the dump has no CREATE DATABASE or USE line,
it can be loaded into any database, so the mysql client with
labdb_restore as its default database recreates both tables there.

The grader compares the tables and every row of labdb and labdb_restore
and expects labdb itself to be untouched. A dump made with
--databases contains a USE labdb line, which sends the restore back
into labdb instead of labdb_restore, so labdb_restore stays empty.
The -p option with the password attached to it prints a warning about
passwords on the command line; it is harmless here.
