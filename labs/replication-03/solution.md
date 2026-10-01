# replication-03: MySQL multi-master circular replication

## Hints

1. A ring is three ordinary source and replica pairs. Every node is
   the source of exactly one replica, so every node needs a replication
   account, an open port 3306 and its own server ID.
2. Server IDs belong in a file below /etc/my.cnf.d, so they survive a
   restart of mysqld. Fresh nodes all start with the same ID, and a
   replica ignores events that carry its own ID.
3. The statements CHANGE REPLICATION SOURCE TO and START REPLICA set up
   one link. The starting point is the file and position that SHOW
   BINARY LOG STATUS (SHOW MASTER STATUS before MySQL 8.2) reports on
   the source.
4. Without TLS, the default password plugin needs the option
   GET_SOURCE_PUBLIC_KEY=1 on the replica. Look at Last_IO_Error in
   SHOW REPLICA STATUS when a thread does not run.

## Solution

1. [user] On the workstation, load the node addresses from the lab
   configuration and define a helper that runs SQL as MySQL root on a
   node:

   ```bash
   source /opt/linux-labs/lib/load-config.sh
   N1=$(get_node_ip 1); N2=$(get_node_ip 2); N3=$(get_node_ip 3)
   sql() {
     printf '%s\n' "$2" | run_on_node "$1" "sudo mysql -u root -N"
   }
   ```

2. [user] Give every node its own server ID in a configuration file
   (1, 2 and 3), keep binary logging on, and restart mysqld:

   ```bash
   i=0
   for ip in "$N1" "$N2" "$N3"; do
     i=$((i + 1))
     CNF=/etc/my.cnf.d/replication.cnf
     printf '[mysqld]\nserver-id=%s\nlog-bin=mysql-bin\n' "$i" |
       run_on_node "$ip" "sudo tee $CNF >/dev/null"
     run_on_node "$ip" "sudo systemctl restart mysqld"
   done
   ```

3. [user] Open the MySQL port on all three nodes:

   ```bash
   for ip in "$N1" "$N2" "$N3"; do
     FW="sudo firewall-cmd"
     run_on_node "$ip" "$FW --permanent --add-port=3306/tcp"
     run_on_node "$ip" "$FW --reload"
   done
   ```

4. [user] Create the replication account on every node. Every node is
   the source of one replica, so all three need it:

   ```bash
   for ip in "$N1" "$N2" "$N3"; do
     sql "$ip" "CREATE USER IF NOT EXISTS 'repl'@'%'
       IDENTIFIED BY 'replpassword';
       GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';"
   done
   ```

5. [user] Define a helper that reads the current binary log position
   of a source and points a replica at it, then close the ring. MySQL
   8.2 and later use SHOW BINARY LOG STATUS, earlier releases SHOW
   MASTER STATUS:

   ```bash
   link() {   # link <replica ip> <source ip>
     local file pos
     read -r file pos _ <<< "$(sql "$2" "SHOW BINARY LOG STATUS" \
       2>/dev/null || sql "$2" "SHOW MASTER STATUS")"
     sql "$1" "CHANGE REPLICATION SOURCE TO
       SOURCE_HOST='$2', SOURCE_USER='repl',
       SOURCE_PASSWORD='replpassword',
       SOURCE_LOG_FILE='$file', SOURCE_LOG_POS=$pos,
       GET_SOURCE_PUBLIC_KEY=1; START REPLICA;"
   }
   link "$N2" "$N1"
   link "$N3" "$N2"
   link "$N1" "$N3"
   ```

6. [user] Check that every replica runs both threads. Each node
   should print Source_Host, then Yes for the I/O and the SQL thread:

   ```bash
   for ip in "$N1" "$N2" "$N3"; do
     sql "$ip" "SHOW REPLICA STATUS\\G" |
       grep -E 'Source_Host|Replica_(IO|SQL)_Running:'
   done
   ```

## Verification

```bash
labctl grade replication-03
```

## Explanation

The ring is three ordinary source and replica pairs: node 2 reads the
binary log of node 1, node 3 reads node 2, and node 1 reads node 3.
Binary logging is already on by default in MySQL 8.0, but the server
ID is 1 on every freshly installed node, so each node needs its own
value in a configuration file (a SET GLOBAL would be lost at the next
restart).

The unique server ID is also what stops the loop. Every event carries
the ID of the server where it was first written. A replica skips events
that carry its own ID, so a change made on node 1 travels through nodes
2 and 3 and is dropped when it comes back to node 1. Two nodes with the
same ID would silently discard each other's changes. Nodes 2 and 3 pass
the events they apply on to the next replica because log_replica_updates
is on by default.

The replication account is created before the log positions are read.
The CREATE USER statements are then already behind the starting
position, so no replica tries to create an account that exists. The
account uses the default caching_sha2_password plugin, and without TLS
the replica needs GET_SOURCE_PUBLIC_KEY=1 to log in. Port 3306/tcp
must be open on every node, because every node is a source.

Ring replication has no conflict detection. If two nodes change the same
row at the same time, the nodes end up with different values and
replication does not report it. Setting auto_increment_increment to 3
and a different auto_increment_offset on each node keeps generated keys
from colliding.
