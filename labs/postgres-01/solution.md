# postgres-01: PostgreSQL installation and first start

## Solution

1. [sudo] Install the server package. The default module stream
   (version 10 on Rocky 8) or the default version (13 on Rocky 9)
   is used:

   ```bash
   sudo dnf install -y postgresql-server
   ```

2. [sudo] Initialise the cluster in /var/lib/pgsql/data:

   ```bash
   sudo postgresql-setup --initdb
   ```

3. [sudo] Start the service and enable it at boot:

   ```bash
   sudo systemctl enable --now postgresql
   ```

4. [sudo] Check the listening port and connect as the postgres user:

   ```bash
   sudo ss -tlnp | grep 5432
   cd /tmp && sudo -u postgres psql -d postgres -c 'SELECT version();'
   ```

## Verification

```bash
labctl grade postgres-01
```

## Explanation

The package installs the binaries and the unit file but creates no
database. postgresql-setup --initdb runs initdb for the data directory
that the unit expects, and the service fails to start until that has
been done. The default configuration listens on localhost only, which
is enough for port 5432 to be served and for the local socket
connection. The postgres user has peer authentication on the socket, so
the query must run as that operating system user; running psql from /tmp
avoids the "could not change directory" warning when the current
directory is not readable by postgres.
