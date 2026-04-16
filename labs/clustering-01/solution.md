# Clustering 01 Solution - Basic Pacemaker/Corosync HA Cluster

## Overview
This solution sets up a basic 3-node Pacemaker/Corosync HA cluster with Apache as a managed resource.

## Architecture
- **Cluster Formation**: 3 nodes communicating via Corosync
- **Resource Manager**: Pacemaker
- **Managed Resource**: Apache web server (HA enabled)
- **Quorum**: 2 nodes (simple majority)

## Step 1: Install Pacemaker and Corosync on All Nodes

Pacemaker is in the High Availability repo — enable it explicitly:

```bash
# On all 3 nodes (servera, serverb, serverc)
sudo dnf install -y --enablerepo=ha pacemaker corosync pcs httpd
```

## Step 2: Create the Corosync Log Directory

The log directory is not created automatically and corosync will fail to start without it:

```bash
# On all 3 nodes
sudo mkdir -p /var/log/corosync
```

## Step 3: Generate Cluster Authentication Key

```bash
# On Node 1 (servera) only
sudo corosync-keygen -l
sudo chmod 400 /etc/corosync/authkey
```

## Step 4: Configure Corosync on Node 1

Get node IPs first:
```bash
source /opt/linux-labs/lib/load-config.sh
load_lab_config
NODE1_IP=$(get_node_ip 1)
NODE2_IP=$(get_node_ip 2)
NODE3_IP=$(get_node_ip 3)
```

Create Corosync configuration — `nodelist` must be a top-level block, not nested inside `totem`:

```bash
sudo tee /etc/corosync/corosync.conf > /dev/null <<EOF
totem {
    version: 2
    cluster_name: ha_cluster
    transport: udpu
    interface {
        ringnumber: 0
        bindnetaddr: 0.0.0.0
        mcastport: 5405
        ttl: 1
    }
}

nodelist {
    node {
        ring0_addr: $NODE1_IP
        nodeid: 1
    }
    node {
        ring0_addr: $NODE2_IP
        nodeid: 2
    }
    node {
        ring0_addr: $NODE3_IP
        nodeid: 3
    }
}

quorum {
    provider: corosync_votequorum
    expected_votes: 3
    two_node: 0
    wait_for_all: 0
}

logging {
    to_logfile: yes
    logfile: /var/log/corosync/corosync.log
    to_syslog: yes
    timestamp: on
}
EOF
```

**Important**: `nodelist` must be a top-level block. Nesting it inside `totem` causes a parse error.

## Step 5: Distribute Config and Authkey to Other Nodes

Direct `scp` between nodes requires root SSH access which is not configured. Copy via workstation instead:

```bash
# From workstation — read from Node 1 and write to Node 2 and 3
for node in $NODE2_IP $NODE3_IP; do
  ssh opsadmin@$NODE1_IP "sudo cat /etc/corosync/authkey" | \
    ssh opsadmin@$node "sudo tee /etc/corosync/authkey > /dev/null && sudo chmod 400 /etc/corosync/authkey"

  ssh opsadmin@$NODE1_IP "sudo cat /etc/corosync/corosync.conf" | \
    ssh opsadmin@$node "sudo tee /etc/corosync/corosync.conf > /dev/null"
done
```

## Step 6: Configure Firewall and Start Services

```bash
# On all 3 nodes
sudo firewall-cmd --permanent --add-service=high-availability
sudo firewall-cmd --reload
sudo systemctl enable --now corosync pacemaker
```

## Step 7: Verify Cluster is Healthy

```bash
# On Node 1 — wait a few seconds after starting services
sudo crm_mon -1

# Should show:
# Current DC: servera - partition with quorum
# 3 nodes configured
# Online: [ servera serverb serverc ]
```

Check node membership directly:
```bash
sudo crm_node -l
# Should list all 3 nodes as "member"
```

## Step 8: Disable STONITH (Required Without Fence Devices)

Pacemaker will not start resources if STONITH is enabled but no fence devices are configured:

```bash
# On Node 1
sudo pcs property set stonith-enabled=false
```

## Step 9: Install Apache and Create Unique Content

```bash
# On Node 1
echo "HA Cluster - servera" | sudo tee /var/www/html/index.html
sudo systemctl disable httpd   # Let Pacemaker manage it, do not start manually

# On Node 2
echo "HA Cluster - serverb" | sudo tee /var/www/html/index.html
sudo systemctl disable httpd

# On Node 3
echo "HA Cluster - serverc" | sudo tee /var/www/html/index.html
sudo systemctl disable httpd
```

## Step 10: Add Apache as a Pacemaker Resource

```bash
# On Node 1
sudo pcs resource create apache_web ocf:heartbeat:apache \
  configfile=/etc/httpd/conf/httpd.conf \
  op monitor interval=1min
```

The resource starts automatically after creation. Do not call `pcs resource start` — that subcommand does not exist in pcs 0.10+. Use `pcs resource enable` if the resource is stopped.

## Step 11: Verify Resource is Running

```bash
sudo crm_mon -1
# Should show:
# Active Resources:
#   * apache_web (ocf::heartbeat:apache): Started servera

sudo pcs resource status
```

## Verify

```bash
sudo labctl grade clustering-01
```

## Troubleshooting

**Corosync fails to start:**
```bash
# Check for parse errors
sudo corosync -f

# Common causes:
# - /var/log/corosync/ directory does not exist
# - nodelist nested inside totem block (must be top-level)
```

**Pacemaker starts but shows 0 nodes:**
```bash
# Wait ~10 seconds after starting corosync for Pacemaker to discover nodes
sudo crm_mon -1
sudo crm_node -l
```

**Resource stays Stopped:**
```bash
# Most likely cause: STONITH is enabled with no fence devices
sudo pcs property set stonith-enabled=false
sudo pcs resource cleanup apache_web
```

**Stray httpd process blocking port 80:**
```bash
# Happens if debug-start was used; kill it before letting Pacemaker manage
sudo pkill httpd
sudo pcs resource cleanup apache_web
```

Check Corosync ring status:
```bash
sudo corosync-cfgtool -s
sudo corosync-quorumtool
```

## How It Works

1. **Corosync**: Cluster communication — unicast UDP (udpu) on port 5405, Totem protocol
2. **Pacemaker**: Resource manager — starts/stops/monitors Apache, handles failover
3. **Quorum**: 2 of 3 nodes required; partition that loses quorum stops resources
4. **OCF Resource Agent**: `ocf:heartbeat:apache` controls httpd via start/stop/monitor actions

## Key Configuration Notes

- `transport: udpu` — required for VM environments (unicast, no multicast needed)
- `nodelist` at top level — not inside `totem`; each node needs `ring0_addr` and `nodeid`
- `expected_votes: 3` — quorum threshold is 2
- `stonith-enabled=false` — necessary in lab environments without real fence devices
