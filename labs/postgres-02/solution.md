# postgres-02: PostgreSQL database and role management

## Hints

1. Two things are needed: the server must ask for a password on TCP
   connections, and the database objects and privileges must exist.
   Look at the authentication file first.
2. The file is /var/lib/pgsql/data/pg_hba.conf. The localhost lines
   use the ident method, which ignores passwords. Choose a method
   that checks them, and reload the service afterwards.
3. Create the role with LOGIN and PASSWORD, and without the
   administrative attributes. Create the database as the postgres
   user. Connecting, schema use and table access are separate
   privileges, each given with GRANT.
4. In labdb, grant USAGE on the public schema and the four table
   privileges on users. An id column of type SERIAL also needs a
   grant on its sequence before labuser can insert.

## Solution

1. [sudo] Switch the localhost TCP rules in pg_hba.conf from ident to
   password authentication and reload the server:

   ```bash
   sudo sed -i -E \
     's/(127\.0\.0\.1\/32|::1\/128)(\s+)ident/\1\2md5/' \
     /var/lib/pgsql/data/pg_hba.conf
   sudo grep '^host' /var/lib/pgsql/data/pg_hba.conf
   sudo systemctl reload postgresql
   ```

2. [sudo] Create the role and the database, and allow the role to
   connect:

   ```bash
   sudo -iu postgres psql \
     -c "CREATE ROLE labuser WITH LOGIN PASSWORD 'userpass123';" \
     -c "CREATE DATABASE labdb;" \
     -c "GRANT CONNECT ON DATABASE labdb TO labuser;"
   ```

3. [sudo] In labdb, grant schema access, create the table, grant
   table privileges and insert two rows:

   ```bash
   sudo -iu postgres psql -d labdb \
     -c "GRANT USAGE ON SCHEMA public TO labuser;" \
     -c "CREATE TABLE users (id SERIAL PRIMARY KEY, name TEXT NOT NULL,
     email TEXT NOT NULL);" \
     -c "GRANT SELECT, INSERT, UPDATE, DELETE ON users TO labuser;" \
     -c "GRANT USAGE, SELECT ON SEQUENCE users_id_seq TO labuser;" \
     -c "INSERT INTO users (name, email)
     VALUES ('John', 'a@example.com'), ('Jane', 'b@example.com');"
   ```

4. [user] Connect as labuser over TCP:

   ```bash
   PGPASSWORD=userpass123 psql -h 127.0.0.1 -U labuser -d labdb \
     -c 'SELECT * FROM users;'
   ```

## Verification

```bash
sudo -iu postgres psql -d labdb -c '\dp users'
sudo -iu postgres psql -c '\du labuser'
labctl grade postgres-02
```

## Explanation

On Rocky Linux the default pg_hba.conf lets 127.0.0.1 and ::1 connect
with the ident method, which asks the operating system for the client
user name and ignores passwords. Changing the method to md5 makes the
server ask for the password. The change takes effect on a reload, a
restart is not needed. Both the IPv4 and the IPv6 line are changed
because the name localhost can resolve to either.

A role that is created with LOGIN and without SUPERUSER, CREATEDB or
CREATEROLE has no administrative privileges. CONNECT on the database,
USAGE on the schema and the four table privileges are separate grants.
The sequence grant is not graded, but without it labuser cannot insert
rows into a table whose id column is SERIAL.

The grader also checks that a wrong password is rejected, so a
pg_hba.conf with the trust method fails.
