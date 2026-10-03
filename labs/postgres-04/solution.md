# postgres-04: PostgreSQL that does not start

## Hints

1. Start with the service. The command systemctl status and the
   journal of the unit show why postgresql stopped. Once the server
   gets far enough to start its logging collector, the messages go to
   its own log files in /var/lib/pgsql/data/log instead, so read the
   newest file there as well.
2. PostgreSQL checks the mode of its data directory before anything
   else. The FATAL message names the modes it accepts.
3. SELinux lets the PostgreSQL domain bind only to ports of one port
   type. The command semanage port in list mode shows which ports
   have it, and ausearch shows the denial. Give the port that type
   instead of making a domain permissive.
4. The server reads pg_hba.conf at every start, and one wrong word in
   it stops the server. The log names the line, and the comments at
   the top of the file list the valid authentication methods.

## Solution

1. [sudo] Look at the service and its journal:

   ```bash
   systemctl status postgresql
   sudo journalctl -u postgresql -n 20 --no-pager
   ```

   The journal shows 'data directory "/var/lib/pgsql/data" has group
   or world access' (PostgreSQL 10, Rocky 8) or 'has invalid
   permissions' (PostgreSQL 13, Rocky 9). The directory has mode
   0755.

2. [sudo] Give the data directory the mode 0700, which both versions
   accept, and try again:

   ```bash
   ls -ld /var/lib/pgsql/data
   sudo chmod 0700 /var/lib/pgsql/data
   sudo systemctl start postgresql
   ```

3. [sudo] The start fails again. Find the new error in the journal
   (Rocky 8) or in the newest server log (Rocky 9):

   ```bash
   sudo journalctl -u postgresql -n 20 --no-pager
   sudo ls -lt /var/lib/pgsql/data/log
   sudo tail -n 20 /var/lib/pgsql/data/log/postgresql-$(date +%a).log
   ```

   The server may not bind to 127.0.0.1: "Permission denied". The
   configuration sets port 5433:

   ```bash
   sudo grep -n '^port' /var/lib/pgsql/data/postgresql.conf
   ```

4. [sudo] Confirm the SELinux denial and look at the port type of
   PostgreSQL. Port 5433 does not have it:

   ```bash
   sudo ausearch -m AVC -ts recent | grep name_bind
   sudo semanage port -l | grep postgresql
   ```

5. [sudo] Give port 5433 the type postgresql_port_t and try again:

   ```bash
   sudo semanage port -a -t postgresql_port_t -p tcp 5433
   sudo systemctl start postgresql
   ```

6. [sudo] The start still fails. The journal now only says that the
   output goes to the logging collector, so read the server log:

   ```bash
   sudo tail -n 5 /var/lib/pgsql/data/log/postgresql-$(date +%a).log
   ```

   It shows 'invalid authentication method "scram-sha256"' and the
   line of pg_hba.conf. The method is called scram-sha-256.

7. [sudo] Correct the method on that line, then start the service
   and enable it at boot:

   ```bash
   sudo grep -n scram /var/lib/pgsql/data/pg_hba.conf
   sudo sed -i 's/scram-sha256$/scram-sha-256/' \
       /var/lib/pgsql/data/pg_hba.conf
   sudo systemctl enable --now postgresql
   sudo ss -tlnp | grep 5433
   ```

8. [user] Log in as labapp over TCP and read the table:

   ```bash
   PGPASSWORD=Stock-2026 psql -h 127.0.0.1 -p 5433 -U labapp \
       -d labdb -c 'SELECT count(*) FROM inventory'
   ```

## Verification

```bash
systemctl is-enabled postgresql
labctl grade postgres-04
```

## Explanation

The faults sit in the order in which the server checks them at start,
so each fix shows the next one. PostgreSQL refuses a data directory
that other users can read: version 10 accepts only 0700, version 13
also 0750 when the group needs read access. The default 0700 works on
both.

SELinux confines the postmaster to the domain postgresql_t, which may
bind only to ports of the type postgresql_port_t (5432 and 9898 by
default). A new port in postgresql.conf therefore needs a persistent
port rule from semanage port. setenforce 0, a permissive domain or an
audit2allow module would hide the denial instead, and the grader
rejects all three.

The server loads pg_hba.conf at start and stops when a line cannot be
parsed. By then the logging collector runs, so the reason is only in
/var/lib/pgsql/data/log, not in the journal. On Rocky 9 the collector
already starts before the sockets are opened, which is why the bind
error is in the server log there and in the journal on Rocky 8.
Changing the method to trust or deleting the line would not do: trust
accepts any password, and without the line labapp falls through to
ident, which fails over TCP.
