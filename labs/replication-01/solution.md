# MySQL Master-Slave Replication Setup (replication-01)

## Overview

MySQL master-slave replication allows you to replicate data from a master database server to one or more slave servers. The master server generates binary logs, and slave servers read these logs to stay synchronized.

## Prerequisites

- Multi-node lab enabled: `labctl configure set NODES_ENABLED true`
- At least 2 nodes configured: `labctl configure set NODE_COUNT 2`
- SSH key configured: `labctl configure set SSH_KEY_PATH ~/.ssh/id_rsa`
- MySQL installed and running on both nodes

## Step-by-Step Solution

### Step 1: Get Node Information

First, load the configuration and identify your master and slave nodes:

```bash
source /opt/linux-labs/lib/load-config.sh
MASTER_IP=$(echo "$(get_all_node_ips)" | awk '{print $1}')
SLAVE_IP=$(echo "$(get_all_node_ips)" | awk '{print $2}')
echo "Master: $MASTER_IP"
echo "Slave: $SLAVE_IP"
```

### Step 2: Configure Master for Replication

On the master node, enable binary logging by modifying MySQL configuration:

```bash
ssh -i ~/.ssh/id_rsa root@$MASTER_IP << 'MASTER_EOF'
# Add binary logging to MySQL configuration
sudo tee -a /etc/my.cnf.d/mysql-server.cnf << 'CONFIG'

# Binary logging for replication
log-bin=mysql-bin
server-id=1
binlog-format=ROW
CONFIG

# Restart MySQL to apply changes
sudo systemctl restart mysqld

# Verify binary logging is enabled
sudo mysql -u root -e "SHOW VARIABLES LIKE 'log_bin';"
MASTER_EOF
```

### Step 3: Create Replication User on Master

Create a dedicated user for replication on the master:

```bash
ssh -i ~/.ssh/id_rsa root@$MASTER_IP << 'MASTER_EOF'
sudo mysql -u root << 'SQL'
-- Create replication user
CREATE USER 'repl'@'%' IDENTIFIED BY 'replpassword';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
FLUSH PRIVILEGES;

-- Verify user was created
SELECT User, Host FROM mysql.user WHERE User='repl';
SQL
MASTER_EOF
```

### Step 4: Get Master Binary Log Position

Capture the current binary log file and position on the master:

```bash
ssh -i ~/.ssh/id_rsa root@$MASTER_IP << 'MASTER_EOF'
sudo mysql -u root -e "SHOW MASTER STATUS\G" | tee /tmp/master_status.txt
MASTER_EOF
```

This will show output like:
```
File: mysql-bin.000001
Position: 154
```

Save these values - you'll need them for the slave configuration.

### Step 5: Configure Slave for Replication

On the slave node, configure it to replicate from the master:

```bash
# First, set the slave configuration
ssh -i ~/.ssh/id_rsa root@$SLAVE_IP << 'SLAVE_EOF'
# Add server-id to MySQL configuration
sudo tee -a /etc/my.cnf.d/mysql-server.cnf << 'CONFIG'

# Replication slave configuration
server-id=2
relay-log=mysql-relay-bin
CONFIG

# Restart MySQL
sudo systemctl restart mysqld
SLAVE_EOF
```

### Step 6: Configure Slave Connection to Master

Set up the slave to connect to the master. Replace FILE and POSITION with values from Step 4:

```bash
ssh -i ~/.ssh/id_rsa root@$SLAVE_IP << 'SLAVE_EOF'
MASTER_IP="YOUR_MASTER_IP"

sudo mysql -u root << 'SQL'
CHANGE MASTER TO
  MASTER_HOST='10.0.0.150',
  MASTER_USER='repl',
  MASTER_PASSWORD='replpassword',
  MASTER_LOG_FILE='mysql-bin.000002',
  MASTER_LOG_POS=827;

-- Verify configuration
SHOW SLAVE STATUS\G
SQL
SLAVE_EOF
```

Replace:
- `MASTER_IP` with your actual master IP (from `get_all_node_ips`)
- `mysql-bin.000001` with the FILE from Step 4
- `154` with the POSITION from Step 4

### Step 7: Start Replication on Slave

```bash
ssh -i ~/.ssh/id_rsa root@$SLAVE_IP << 'SLAVE_EOF'
sudo mysql -u root  << 'SQL'
START SLAVE;

-- Check replication status
SHOW SLAVE STATUS\G
SQL
SLAVE_EOF
```

Look for:
- `Slave_IO_Running: Yes`
- `Slave_SQL_Running: Yes`

If either is "No", check the error with `SHOW SLAVE STATUS\G`

## Verification

### Test Data Replication

Create a test database on the master and verify it appears on the slave:

```bash
# On master: Create test database
ssh -i ~/.ssh/id_rsa root@$MASTER_IP << 'MASTER_EOF'
sudo mysql -u root << 'SQL'
CREATE DATABASE replication_test;
USE replication_test;
CREATE TABLE users (id INT PRIMARY KEY, name VARCHAR(100));
INSERT INTO users VALUES (1, 'Alice'), (2, 'Bob');
SELECT * FROM users;
SQL
MASTER_EOF

# On slave: Verify database exists and has same data
ssh -i ~/.ssh/id_rsa root@$SLAVE_IP << 'SLAVE_EOF'
sudo mysql -u root << 'SQL'
USE replication_test;
SELECT * FROM users;
SQL
SLAVE_EOF
```

Both should show:
```
id | name
1  | Alice
2  | Bob
```

### Monitor Replication Status

On the slave, check replication is working:

```bash
ssh -i ~/.ssh/id_rsa root@$SLAVE_IP << 'SLAVE_EOF'
sudo mysql -u root -e "SHOW SLAVE STATUS\G" | grep -E "Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master"
SLAVE_EOF
```

Expected output:
```
Slave_IO_Running: Yes
Slave_SQL_Running: Yes
Seconds_Behind_Master: 0
```

## Troubleshooting

### Slave Not Connecting

Check the slave error log:
```bash
ssh -i ~/.ssh/id_rsa root@$SLAVE_IP "sudo tail -50 /var/log/mysql/error.log"
```

Common issues:
- Wrong master IP or credentials
- Master firewall blocking port 3306
- Binary log file/position mismatch

### Replication Lag

If `Seconds_Behind_Master` is increasing, the slave is falling behind:
```bash
ssh -i ~/.ssh/id_rsa root@$SLAVE_IP "sudo mysql -u root -e \"SHOW SLAVE STATUS\G\" | grep Seconds_Behind"
```

Check master binary log size and I/O between nodes.

### Reset Replication

To completely reset and start over:

```bash
ssh -i ~/.ssh/id_rsa root@$SLAVE_IP << 'SLAVE_EOF'
sudo mysql -u root << 'SQL'
STOP SLAVE;
RESET SLAVE ALL;
RESET MASTER;
SQL
SLAVE_EOF

ssh -i ~/.ssh/id_rsa root@$MASTER_IP << 'MASTER_EOF'
sudo mysql -u root << 'SQL'
RESET MASTER;
DROP USER 'repl'@'%';
SQL
MASTER_EOF
```

## Key Concepts

- **Binary Log**: A record of all write operations on the master
- **Relay Log**: Temporary storage of binary log events on the slave
- **Slave IO Thread**: Reads binary logs from master
- **Slave SQL Thread**: Applies relay log events to slave database
- **Replication Lag**: Delay between master write and slave application

## Next Steps

After completing this lab, check out:
- `replication-02`: PostgreSQL streaming replication
- `replication-03`: Multi-master circular replication
