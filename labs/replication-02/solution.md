# replication-02: PostgreSQL streaming replication with WAL archiving

## Hints

1. Both nodes need work before the copy is made. Node 1 must listen on
   a non-local address, allow the role repl to connect for replication
   and archive its WAL. Node 2 must start from a copy of node 1.
2. The access rule for replication connections goes into pg_hba.conf
   on node 1, with the database field set to replication. Settings such
   as archive_mode and archive_command can be changed with ALTER SYSTEM,
   and archive_mode takes effect only after a restart.
3. On node 2, read man pg_basebackup. The target directory must be
   empty, and the options -R and -X stream make the copy a ready
   standby. The password for repl has to be available without a prompt,
   see the .pgpass file in the home directory of the postgres user.
4. Check the result with pg_stat_replication on node 1 and
   pg_is_in_recovery() on node 2.

## Solution

Below, <node1-ip> and <node2-ip> are the addresses shown by
`labctl task`. Steps 2 to 7 run on node 1 (the primary), steps 8 to 11
on node 2 (the standby). Open an SSH session to each node as a user
with sudo rights.

1. [user] Open the sessions:

   ```bash
   ssh <user>@<node1-ip>
   ssh <user>@<node2-ip>
   ```

### Node 1 (primary)

2. [sudo] Create the WAL archive directory:

   ```bash
   sudo install -d -o postgres -g postgres -m 700 \
        /var/lib/pgsql/wal_archive
   ```

3. [sudo] Set the replication and archiving parameters (they are
   written to postgresql.auto.conf):

   ```bash
   cd /tmp
   ARCH=/var/lib/pgsql/wal_archive
   sudo -u postgres psql \
        -c "ALTER SYSTEM SET listen_addresses TO '*'" \
        -c "ALTER SYSTEM SET wal_level TO replica" \
        -c "ALTER SYSTEM SET max_wal_senders TO 5" \
        -c "ALTER SYSTEM SET archive_mode TO on" \
        -c "ALTER SYSTEM SET archive_command TO 'cp %p $ARCH/%f'"
   ```

4. [sudo] Allow the standby to connect as repl for replication:

   ```bash
   HBA=/var/lib/pgsql/data/pg_hba.conf
   echo "host replication repl <node2-ip>/32 md5" | sudo tee -a $HBA
   ```

5. [sudo] Open the PostgreSQL port if firewalld is running:

   ```bash
   sudo firewall-cmd --permanent --add-service=postgresql
   sudo firewall-cmd --reload
   ```

6. [sudo] Restart PostgreSQL (archive_mode needs a restart) and enable
   it:

   ```bash
   sudo systemctl enable postgresql
   sudo systemctl restart postgresql
   ```

7. [sudo] Create the replication role:

   ```bash
   cd /tmp
   sudo -u postgres psql \
        -c "CREATE ROLE repl LOGIN REPLICATION PASSWORD 'replpassword'"
   ```

### Node 2 (standby)

8. [sudo] Make sure PostgreSQL is stopped and the data directory is
   empty:

   ```bash
   sudo systemctl stop postgresql
   ls -A /var/lib/pgsql/data
   ```

9. [sudo] Store the replication password for the postgres user:

   ```bash
   PGPASS=/var/lib/pgsql/.pgpass
   echo '<node1-ip>:5432:*:repl:replpassword' | \
        sudo -u postgres tee $PGPASS
   sudo chmod 600 $PGPASS
   ```

10. [sudo] Copy the primary with a base backup. The option -R writes
    the standby configuration, which differs between PostgreSQL 10
    (recovery.conf) and 12 or later (standby.signal):

    ```bash
    cd /tmp
    sudo -u postgres pg_basebackup -h <node1-ip> -U repl -w -P -R \
         -X stream -D /var/lib/pgsql/data
    ```

11. [sudo] Start the standby and enable it:

    ```bash
    sudo systemctl enable --now postgresql
    ```

## Verification

On node 2, the standby is in recovery and receives WAL:

```bash
cd /tmp
sudo -u postgres psql -c "SELECT pg_is_in_recovery()"
sudo -u postgres psql -c "SELECT status FROM pg_stat_wal_receiver"
```

On node 1, the standby is listed as streaming and segments arrive in
the archive:

```bash
cd /tmp
sudo -u postgres psql \
     -c "SELECT client_addr, state FROM pg_stat_replication"
sudo -u postgres psql -c "SELECT pg_switch_wal()"
sudo ls /var/lib/pgsql/wal_archive
```

Then grade from the workstation:

```bash
labctl grade replication-02
```

## Explanation

The primary ships its write-ahead log to the standby over a normal
PostgreSQL connection. That connection needs four things on node 1: a
listening address other than localhost, a pg_hba.conf line of type
replication for the role, an open port 5432 and a role with the
REPLICATION attribute. wal_level replica and max_wal_senders above 0
are the defaults on PostgreSQL 10 and later, so the lines only make
them explicit.

WAL archiving is independent of streaming. archive_mode is read at
server start, so a restart is required; a reload is not enough. The
archive_command must succeed, otherwise segments pile up in pg_wal.

pg_basebackup refuses a non-empty target directory. With -R it writes
primary_conninfo and puts the server in standby mode, so the same
command works on Rocky 8 (PostgreSQL 10) and Rocky 9 (PostgreSQL 13).
The password goes into ~postgres/.pgpass, because the walreceiver
process of the standby needs it on every reconnect and pg_basebackup
may not store it in the generated configuration.

Promoting the standby (pg_ctl promote or SELECT pg_promote() on 12 and
later) ends recovery, so do it only after grading.
