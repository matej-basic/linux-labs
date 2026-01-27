# PostgreSQL Streaming Replication Setup (replication-02)

## Overview

PostgreSQL streaming replication continuously streams Write-Ahead Log (WAL) records from the primary server to standby replicas. This provides near-real-time replication with minimal lag, suitable for high-availability deployments.

## Prerequisites

- Multi-node lab enabled: `labctl configure set NODES_ENABLED true`
- At least 2 nodes configured: `labctl configure set NODE_COUNT 2`
- SSH key configured: `labctl configure set SSH_KEY_PATH ~/.ssh/id_rsa`
- PostgreSQL installed and initialized on all nodes

## Architecture

```
Primary Server (Node 1)
    ├─ Generates WAL records
    ├─ Archives WALs to safe location
    └─ Streams WALs to standbys

Standby 1 (Node 2)
    ├─ Receives WAL stream
    ├─ Applies changes to replica
    └─ Can be promoted to primary

Standby 2 (Node 3, optional)
    ├─ Receives WAL stream
    ├─ Applies changes to replica
    └─ Can be promoted to primary
```

## Step-by-Step Solution

### Step 1: Get Node Information

```bash
source /opt/linux-labs/lib/load-config.sh
PRIMARY_IP=$(echo "$(get_all_node_ips)" | awk '{print $1}')
STANDBY1_IP=$(echo "$(get_all_node_ips)" | awk '{print $2}')
echo "Primary: $PRIMARY_IP"
echo "Standby 1: $STANDBY1_IP"
```

### Step 2: Configure Primary Server

On the primary, modify PostgreSQL configuration for replication:

```bash
ssh -i ~/.ssh/id_rsa root@$PRIMARY_IP << 'PRIMARY_EOF'
# Backup original configuration to a safe location (not in data directory)
sudo cp /var/lib/pgsql/data/postgresql.conf /var/lib/pgsql/postgresql.conf.bak

# Configure WAL parameters for replication
sudo tee -a /var/lib/pgsql/data/postgresql.conf << 'CONFIG'
# Replication parameters
max_wal_senders = 5
wal_keep_segments = 32
wal_level = replica
listen_addresses = '*'
CONFIG

# Ensure postgres user can read the config file
sudo chown postgres:postgres /var/lib/pgsql/data/postgresql.conf
sudo chmod 644 /var/lib/pgsql/data/postgresql.conf

# Allow replication connections
sudo tee -a /var/lib/pgsql/data/pg_hba.conf << 'HBA'
# Replication connections
host    replication     repl            0.0.0.0/0               md5
HBA

# Ensure postgres user can read pg_hba.conf
sudo chown postgres:postgres /var/lib/pgsql/data/pg_hba.conf
sudo chmod 644 /var/lib/pgsql/data/pg_hba.conf

# Restart PostgreSQL
sudo systemctl restart postgresql
sudo -u postgres psql -c "SHOW wal_level;"
PRIMARY_EOF
```

### Step 3: Create Replication User on Primary

```bash
ssh -i ~/.ssh/id_rsa root@$PRIMARY_IP << 'PRIMARY_EOF'
sudo -u postgres psql << 'SQL'
-- Create replication user with superuser privileges
CREATE ROLE repl WITH LOGIN REPLICATION PASSWORD 'replpassword';

-- Verify user was created
SELECT rolname, rolcanlogin, rolcanconnect FROM pg_roles WHERE rolname = 'repl';
SQL
PRIMARY_EOF
```

### Step 4: Create Base Backup for Standby

On the standby, take a base backup from the primary using the PGPASSWORD environment variable:

```bash
ssh -i ~/.ssh/id_rsa root@$STANDBY1_IP << STANDBY_EOF
# Stop PostgreSQL if running
sudo systemctl stop postgresql 2>/dev/null || true

# Remove old data directory
sudo rm -rf /var/lib/pgsql/data

# Create data directory with proper permissions
sudo mkdir -p /var/lib/pgsql/data
sudo chown postgres:postgres /var/lib/pgsql/data
sudo chmod 700 /var/lib/pgsql/data

# Create pg_basebackup from primary with password
export PGPASSWORD='replpassword'
sudo -u postgres pg_basebackup \
    -h $PRIMARY_IP \
    -U repl \
    -D /var/lib/pgsql/data \
    -Fp \
    -Xs \
    -P

# Verify backup was created
ls -la /var/lib/pgsql/data/
STANDBY_EOF
```

**Note:** Make sure Step 3 (Create Replication User) has been completed first, otherwise the repl user won't exist and authentication will fail.

### Step 5: Create recovery.conf on Standby

Configure the standby to recover continuously from the primary:

```bash
ssh -i ~/.ssh/id_rsa root@$STANDBY1_IP << 'STANDBY_EOF'
sudo tee /var/lib/pgsql/data/recovery.conf << 'RECOVERY'
# Standby recovery configuration
standby_mode = 'on'
primary_conninfo = 'host=10.0.0.150 port=5432 user=repl password=replpassword'
restore_command = 'test -f /var/lib/pgsql/archive/%f && cat /var/lib/pgsql/archive/%f || exit 1'
trigger_file = '/var/lib/pgsql/data/failover.trigger'
RECOVERY

# Fix permissions
sudo chown postgres:postgres /var/lib/pgsql/data/recovery.conf
sudo chmod 600 /var/lib/pgsql/data/recovery.conf
STANDBY_EOF
```

Replace `PRIMARY_IP` with your actual primary IP.

### Step 6: Start PostgreSQL on Standby

```bash
ssh -i ~/.ssh/id_rsa root@$STANDBY1_IP << 'STANDBY_EOF'
# Start PostgreSQL
sudo systemctl start postgresql

# Check recovery status (should show 't' for true - in recovery)
cd /tmp && sudo -u postgres psql -c "SELECT pg_is_in_recovery();"

# Check streaming replication status
cd /tmp && sudo -u postgres psql -c "SELECT * FROM pg_stat_wal_receiver\G"
STANDBY_EOF
```

### Step 7: Verify Replication on Primary

On the primary, check connected replicas:

```bash
ssh -i ~/.ssh/id_rsa root@$PRIMARY_IP << 'PRIMARY_EOF'
cd /tmp && sudo -u postgres psql << 'SQL'
-- Show connected WAL senders (replication clients)
SELECT client_addr, state, sync_state, replay_lsn FROM pg_stat_replication;

-- Check WAL generation
SELECT * FROM pg_current_wal_lsn();
SQL
PRIMARY_EOF
```

## Verification

### Test Data Replication

Create a table on the primary and verify it appears on the standby:

```bash
# On primary: Create test table
ssh -i ~/.ssh/id_rsa root@$PRIMARY_IP << 'PRIMARY_EOF'
cd /tmp && sudo -u postgres psql << 'SQL'
CREATE TABLE replication_test (
    id SERIAL PRIMARY KEY,
    name TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

INSERT INTO replication_test (name) VALUES 
    ('Primary to Standby'),
    ('Streaming Replication');

SELECT * FROM replication_test;
SQL
PRIMARY_EOF

# On standby: Verify table and data
ssh -i ~/.ssh/id_rsa root@$STANDBY1_IP << 'STANDBY_EOF'
cd /tmp && sudo -u postgres psql << 'SQL'
SELECT * FROM replication_test;
SQL
STANDBY_EOF
```

Both should show the same data.

### Monitor Replication Progress

On the primary, monitor replication:

```bash
ssh -i ~/.ssh/id_rsa root@$PRIMARY_IP << 'PRIMARY_EOF'
cd /tmp && sudo -u postgres psql << 'SQL'
SELECT 
    client_addr,
    usename,
    application_name,
    state,
    sync_state,
    write_lag,
    flush_lag,
    replay_lag
FROM pg_stat_replication;
SQL
PRIMARY_EOF
```

Look for:
- `state`: 'streaming' (actively replicating)
- `sync_state`: 'async' (asynchronous) or 'sync' (synchronous)
- `write_lag`, `flush_lag`, `replay_lag`: Should be small (< 1 second)

### Promote Standby to Primary (Optional)

If you want to test failover:

```bash
ssh -i ~/.ssh/id_rsa root@$STANDBY1_IP << 'STANDBY_EOF'
# Create trigger file to promote standby
sudo touch /var/lib/pgsql/data/failover.trigger

# Wait a few seconds for promotion
sleep 3

# Check it's no longer in recovery
cd /tmp && sudo -u postgres psql -c "SELECT pg_is_in_recovery();"
# Should return 't' = false, meaning now a primary
STANDBY_EOF
```

## Key Concepts

- **WAL (Write-Ahead Log)**: Records all database changes before they're applied
- **Streaming Replication**: Continuous real-time transfer of WAL records to standbys
- **Synchronous Replication**: Primary waits for standby confirmation (guarantees consistency)
- **Asynchronous Replication**: Primary doesn't wait (faster but potential data loss on failure)
- **Base Backup**: Complete copy of primary database for standby initialization
- **Recovery Configuration**: Tells standby how to connect to primary and recover

## Troubleshooting

### Standby Not Connecting

Check the PostgreSQL error log on standby:
```bash
ssh -i ~/.ssh/id_rsa root@$STANDBY1_IP "cd /tmp && sudo -u postgres tail -50 /var/lib/pgsql/data/log/*"
```

Common issues:
- Wrong primary IP in recovery.conf
- Replication user doesn't exist or wrong password
- Primary firewall blocking port 5432
- pg_hba.conf not allowing replication connections

### Replication Lag Increasing

Monitor the LSN (Log Sequence Number) positions:

```bash
ssh -i ~/.ssh/id_rsa root@$PRIMARY_IP << 'PRIMARY_EOF'
cd /tmp && sudo -u postgres psql -c "SELECT pg_current_wal_lsn();"
PRIMARY_EOF

ssh -i ~/.ssh/id_rsa root@$STANDBY1_IP << 'STANDBY_EOF'
cd /tmp && sudo -u postgres psql -c "SELECT pg_last_wal_receive_lsn();"
STANDBY_EOF
```

If standby LSN is falling behind, check network and primary load.

## Next Steps

- `replication-03`: Multi-master replication using logical replication
- Explore pgBackRest for advanced backup and recovery
- Configure Patroni for automated failover

## Additional Commands

Monitor replication in real-time:
```bash
# On primary
watch -n 1 'cd /tmp && sudo -u postgres psql -c "SELECT client_addr, state, replay_lsn FROM pg_stat_replication;"'

# On standby
watch -n 1 'cd /tmp && sudo -u postgres psql -c "SELECT status, received_lsn, replayed_lsn FROM pg_stat_wal_receiver;"'
```
