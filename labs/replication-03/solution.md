# MySQL Multi-Master Circular Replication (replication-03)

## Overview

Multi-master replication creates a circular topology where each node is both a master and a slave. In this lab, we configure three MySQL servers in a circular loop: Node A → B → C → A. This allows write operations on any node to eventually reach all other nodes.

## Prerequisites

- Multi-node lab enabled: `labctl configure set NODES_ENABLED true`
- At least 3 nodes configured: `labctl configure set NODE_COUNT 3`
- SSH key configured: `labctl configure set SSH_KEY_PATH ~/.ssh/id_rsa`
- MySQL installed and initialized on all nodes

## Architecture

```
       ┌─────────────┐
       │   Node A    │
       │  Master/    │
       │  Slave (C)  │
       └──────┬──────┘
              │ replicates to B
              │ receives from C
              ▼
       ┌─────────────┐
       │   Node B    │
       │  Master/    │
       │  Slave (A)  │
       └──────┬──────┘
              │ replicates to C
              │ receives from A
              ▼
       ┌─────────────┐
       │   Node C    │
       │  Master/    │
       │  Slave (B)  │
       └──────┬──────┘
              │ replicates to A
              │ receives from B
              │
              └──────────────────┐
                                 ▼ (back to A)
```

## Step-by-Step Solution

### Step 1: Get Node Information

```bash
source /opt/linux-labs/lib/load-config.sh
NODE_A=$(echo "$(get_all_node_ips)" | awk '{print $1}')
NODE_B=$(echo "$(get_all_node_ips)" | awk '{print $2}')
NODE_C=$(echo "$(get_all_node_ips)" | awk '{print $3}')
echo "Node A: $NODE_A"
echo "Node B: $NODE_B"
echo "Node C: $NODE_C"
```

### Step 2: Configure Binary Logging on All Nodes

On each node, enable binary logging with unique server IDs:

**Node A (server-id=1):**
```bash
ssh -i ~/.ssh/id_rsa root@$NODE_A << 'NODE_A_EOF'
# Backup configuration
sudo cp /etc/my.cnf.d/mysql-server.cnf /etc/my.cnf.d/mysql-server.cnf.bak

# Add replication configuration
sudo tee -a /etc/my.cnf.d/mysql-server.cnf << 'CONFIG'

# Multi-master replication configuration
server-id=1
log-bin=mysql-bin
binlog-format=ROW
relay-log=mysql-relay-bin
relay-log-index=mysql-relay-bin.index
CONFIG

sudo systemctl restart mysqld
sudo mysql -u root  -e "SHOW VARIABLES LIKE 'server_id';"
NODE_A_EOF
```

**Node B (server-id=2):**
```bash
ssh -i ~/.ssh/id_rsa root@$NODE_B << 'NODE_B_EOF'
sudo cp /etc/my.cnf.d/mysql-server.cnf /etc/my.cnf.d/mysql-server.cnf.bak
sudo tee -a /etc/my.cnf.d/mysql-server.cnf << 'CONFIG'

server-id=2
log-bin=mysql-bin
binlog-format=ROW
relay-log=mysql-relay-bin
relay-log-index=mysql-relay-bin.index
CONFIG

sudo systemctl restart mysqld
sudo mysql -u root  -e "SHOW VARIABLES LIKE 'server_id';"
NODE_B_EOF
```

**Node C (server-id=3):**
```bash
ssh -i ~/.ssh/id_rsa root@$NODE_C << 'NODE_C_EOF'
sudo cp /etc/my.cnf.d/mysql-server.cnf /etc/my.cnf.d/mysql-server.cnf.bak
sudo tee -a /etc/my.cnf.d/mysql-server.cnf << 'CONFIG'

server-id=3
log-bin=mysql-bin
binlog-format=ROW
relay-log=mysql-relay-bin
relay-log-index=mysql-relay-bin.index
CONFIG

sudo systemctl restart mysqld
sudo mysql -u root  -e "SHOW VARIABLES LIKE 'server_id';"
NODE_C_EOF
```

### Step 3: Create Replication Users on All Nodes

Each node needs to allow replication from its upstream master. Create replication users:

```bash
for node_ip in $NODE_A $NODE_B $NODE_C; do
    ssh -i ~/.ssh/id_rsa root@$node_ip << 'EOF'
sudo mysql -u root  << 'SQL'
CREATE USER 'repl'@'%' IDENTIFIED BY 'replpassword';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
FLUSH PRIVILEGES;
SQL
EOF
done
```

### Step 4: Get Master Positions

Before setting up replication, capture current binary log positions on each node:

```bash
echo "=== Node A Binary Log Position ==="
ssh -i ~/.ssh/id_rsa root@$NODE_A "sudo mysql -u root  -e \"SHOW MASTER STATUS\G\""

echo "=== Node B Binary Log Position ==="
ssh -i ~/.ssh/id_rsa root@$NODE_B "sudo mysql -u root  -e \"SHOW MASTER STATUS\G\""

echo "=== Node C Binary Log Position ==="
ssh -i ~/.ssh/id_rsa root@$NODE_C "sudo mysql -u root  -e \"SHOW MASTER STATUS\G\""
```

Note the File and Position for each node.

### Step 5: Configure Node B to Replicate from Node A (A→B)

```bash
ssh -i ~/.ssh/id_rsa root@$NODE_B << 'EOF'
sudo mysql -u root  << 'SQL'
CHANGE MASTER TO
  MASTER_HOST='10.0.0.150',
  MASTER_USER='repl',
  MASTER_PASSWORD='replpassword',
  MASTER_LOG_FILE='mysql-bin.000001',
  MASTER_LOG_POS=827;

START SLAVE;

-- Verify replication is working
SHOW SLAVE STATUS\G
SQL
EOF
```

Replace `NODE_A_IP` and log file/position from Step 4.

### Step 6: Configure Node C to Replicate from Node B (B→C)

```bash
ssh -i ~/.ssh/id_rsa root@$NODE_C << 'EOF'
sudo mysql -u root  << 'SQL'
CHANGE MASTER TO
  MASTER_HOST='10.0.0.151',
  MASTER_USER='repl',
  MASTER_PASSWORD='replpassword',
  MASTER_LOG_FILE='mysql-bin.000001',
  MASTER_LOG_POS=827;

START SLAVE;

SHOW SLAVE STATUS\G
SQL
EOF
```

Replace `NODE_B_IP` and log file/position from Step 4.

### Step 7: Configure Node A to Replicate from Node C (C→A)

```bash
ssh -i ~/.ssh/id_rsa root@$NODE_A << 'EOF'
sudo mysql -u root  << 'SQL'
CHANGE MASTER TO
  MASTER_HOST='10.0.0.152',
  MASTER_USER='repl',
  MASTER_PASSWORD='replpassword',
  MASTER_LOG_FILE='mysql-bin.000001',
  MASTER_LOG_POS=827;

START SLAVE;

SHOW SLAVE STATUS\G
SQL
EOF
```

Replace `NODE_C_IP` and log file/position from Step 4.

## Verification

### Test Circular Replication

Create a database on Node A and verify it reaches B, then C, then back to A:

```bash
# Write on Node A
ssh -i ~/.ssh/id_rsa root@$NODE_A << 'EOF'
sudo mysql -u root  << 'SQL'
CREATE DATABASE circular_test;
USE circular_test;
CREATE TABLE data (id INT PRIMARY KEY, value TEXT, node INT);
INSERT INTO data VALUES (1, 'Written on Node A', 1);
SELECT * FROM data;
SQL
EOF

# Check Node B
sleep 2
ssh -i ~/.ssh/id_rsa root@$NODE_B << 'EOF'
sudo mysql -u root  << 'SQL'
USE circular_test;
SELECT * FROM data;
-- Add another row on Node B
INSERT INTO data VALUES (2, 'Written on Node B', 2);
SQL
EOF

# Check Node C
sleep 2
ssh -i ~/.ssh/id_rsa root@$NODE_C << 'EOF'
sudo mysql -u root  << 'SQL'
USE circular_test;
SELECT * FROM data;
-- Add another row on Node C
INSERT INTO data VALUES (3, 'Written on Node C', 3);
SQL
EOF

# Check back on Node A (complete circle)
sleep 2
ssh -i ~/.ssh/id_rsa root@$NODE_A << 'EOF'
sudo mysql -u root  << 'SQL'
USE circular_test;
SELECT * FROM data;
-- Should now have rows from A, B, and C
SQL
EOF
```

All three rows should appear on all nodes.

### Check Replication Status

On each node, verify replication status:

```bash
ssh -i ~/.ssh/id_rsa root@$NODE_A "sudo mysql -u root  -e \"SHOW SLAVE STATUS\G\" | grep -E 'Slave_IO_Running|Slave_SQL_Running|Seconds_Behind'"

ssh -i ~/.ssh/id_rsa root@$NODE_B "sudo mysql -u root  -e \"SHOW SLAVE STATUS\G\" | grep -E 'Slave_IO_Running|Slave_SQL_Running|Seconds_Behind'"

ssh -i ~/.ssh/id_rsa root@$NODE_C "sudo mysql -u root  -e \"SHOW SLAVE STATUS\G\" | grep -E 'Slave_IO_Running|Slave_SQL_Running|Seconds_Behind'"
```

All should show:
```
Slave_IO_Running: Yes
Slave_SQL_Running: Yes
Seconds_Behind_Master: 0
```

## Important Considerations

### Avoid Infinite Loops

With circular replication, changes could loop infinitely. MySQL prevents this by:
1. Each node has a unique `server-id`
2. When a node sees a replication event from itself, it ignores it
3. Events include the originating `server-id` in their header

### Conflict Resolution

In multi-master, conflicts can occur when the same row is modified on different nodes:

```bash
# Example of potential conflict:
# Node A: UPDATE data SET value='A' WHERE id=1;
# Node B: UPDATE data SET value='B' WHERE id=1; (at same time)

# Resolution strategies:
# 1. Last-write-wins (default): Later update overwrites earlier
# 2. Column-based: Custom conflict resolution
# 3. Application-level: Handle conflicts in code
```

### Auto-Increment Handling

With multi-master, auto-increment can create duplicates:

```sql
-- Configure safe auto-increment:
-- Node A: auto_increment_offset=1, auto_increment_increment=3
-- Node B: auto_increment_offset=2, auto_increment_increment=3
-- Node C: auto_increment_offset=3, auto_increment_increment=3

-- This makes each node generate different IDs:
-- Node A: 1, 4, 7, 10...
-- Node B: 2, 5, 8, 11...
-- Node C: 3, 6, 9, 12...
```

## Troubleshooting

### Changes Not Replicating

Check replication status:
```bash
ssh -i ~/.ssh/id_rsa root@$NODE_B "sudo mysql -u root  -e \"SHOW SLAVE STATUS\G\" | grep -i error"
```

Common causes:
- Network connectivity between nodes
- Firewall blocking MySQL port 3306
- Binary log position mismatch
- Duplicate primary key errors

### Infinite Replication Loop

If you see events replaying repeatedly:
1. Check server-id is unique on each node
2. Verify SHOW MASTER STATUS shows different binary log files
3. Check for corrupted relay logs

### Reset Multi-Master Topology

To start over:

```bash
for node_ip in $NODE_A $NODE_B $NODE_C; do
    ssh -i ~/.ssh/id_rsa root@$node_ip << 'EOF'
sudo mysql -u root  << 'SQL'
STOP SLAVE;
RESET SLAVE ALL;
RESET MASTER;
DROP USER 'repl'@'%';
SQL
EOF
done
```

## Key Concepts

- **Multi-Master Replication**: Every node is both master and slave
- **Circular Topology**: Nodes form a ring where changes propagate around the circle
- **Server ID**: Unique identifier preventing infinite replication loops
- **Binlog Format**: ROW format recommended for multi-master to reduce conflicts
- **Replication Lag**: Time delay as changes propagate through the circle
- **Conflict Resolution**: Handling simultaneous writes to same row on different nodes

## Next Steps

- Explore Percona XtraDB Cluster (PXC) for synchronous multi-master
- Study Galera Cluster for automatic conflict resolution
- Investigate MySQL Group Replication for enhanced consistency
