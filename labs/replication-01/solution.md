# replication-01: MySQL source-replica replication

## Solution

1. [user] On the workstation, load the node addresses from the lab
   configuration and define a helper that runs SQL as MySQL root on a
   node. Node 1 is the source, node 2 the replica:

   ```bash
   source /opt/linux-labs/lib/load-config.sh
   N1=$(get_node_ip 1); N2=$(get_node_ip 2)
   sql() { echo "$2" | run_on_node "$1" "sudo mysql"; }
   ```

2. [user] Configure the source. MySQL 8 already writes a binary log,
   but set it and the server ID explicitly, then restart mysqld:

   ```bash
   CNF='[mysqld]\nlog-bin=mysql-bin\nserver-id=1\n'
   printf '%b' "$CNF" | run_on_node "$N1" \
     "sudo tee /etc/my.cnf.d/replication.cnf"
   run_on_node "$N1" "sudo systemctl restart mysqld"
   ```

3. [user] Allow connections to port 3306 in the firewall of node 1:

   ```bash
   run_on_node "$N1" "sudo firewall-cmd --permanent --add-service=mysql"
   run_on_node "$N1" "sudo firewall-cmd --reload"
   ```

4. [user] Create the replication account on node 1:

   ```bash
   sql "$N1" "CREATE USER 'repl'@'%' IDENTIFIED BY 'replpassword';
   GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';"
   ```

5. [user] Read the binary log file and position of node 1. MySQL 8.2
   and later know the first statement, older 8.0 releases the second:

   ```bash
   STATUS=$(sql "$N1" "SHOW BINARY LOG STATUS" 2>/dev/null ||
     sql "$N1" "SHOW MASTER STATUS")
   LOGFILE=$(echo "$STATUS" | awk 'NR == 2 { print $1 }')
   LOGPOS=$(echo "$STATUS" | awk 'NR == 2 { print $2 }')
   echo "$LOGFILE $LOGPOS"
   ```

6. [user] Give node 2 its own server ID and a relay log name, then
   restart mysqld:

   ```bash
   CNF='[mysqld]\nserver-id=2\nrelay-log=relay-bin\n'
   printf '%b' "$CNF" | run_on_node "$N2" \
     "sudo tee /etc/my.cnf.d/replication.cnf"
   run_on_node "$N2" "sudo systemctl restart mysqld"
   ```

7. [user] Point node 2 at node 1 and start replication. The public
   key option lets the replica log in with the default password
   plugin over an unencrypted connection:

   ```bash
   sql "$N2" "CHANGE REPLICATION SOURCE TO SOURCE_HOST='$N1',
   SOURCE_USER='repl', SOURCE_PASSWORD='replpassword',
   SOURCE_LOG_FILE='$LOGFILE', SOURCE_LOG_POS=$LOGPOS,
   GET_SOURCE_PUBLIC_KEY=1;
   START REPLICA;"
   ```

## Verification

Both threads must say Yes and the error fields must be empty:

```bash
sql "$N2" 'SHOW REPLICA STATUS\G' | grep -E 'Running:|Error:'
```

Write on node 1 and read on node 2:

```bash
sql "$N1" "CREATE DATABASE replication_test;
CREATE TABLE replication_test.users (id INT PRIMARY KEY, name TEXT);
INSERT INTO replication_test.users VALUES (1, 'Alice');"
sleep 2
sql "$N2" "SELECT * FROM replication_test.users;"
```

Then grade:

```bash
labctl grade replication-01
```

## Explanation

The source writes every change to its binary log. The I/O thread of
the replica copies those events into its relay log and the SQL thread
applies them. The replica needs a starting point, which is why step 5
reads the log file and position before step 7 uses them.

Both nodes start with server ID 1, the MySQL 8 default. A replica
refuses a source that has its own ID, so node 2 needs a different one.
It must be written to an option file (or persisted), or it is lost at
the next restart. The repl account uses the default plugin
caching_sha2_password, which needs TLS or the RSA public key of the
server on the first login. Without GET_SOURCE_PUBLIC_KEY=1 the I/O
thread stays in the Connecting state. A closed port 3306 on node 1
gives the same symptom, and Last_IO_Error in SHOW REPLICA STATUS tells
the two apart.

The statements use the REPLICA and SOURCE keywords. MySQL 8.0.22 and
later accept them, and MySQL 8.4 removed the older MASTER and SLAVE
forms. If you set a MySQL root password, keep it in /root/.my.cnf on
the node, or grading and labctl reset cannot log in.
