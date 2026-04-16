# Clustering 03 Solution - Advanced Cluster Protection

## Overview
This lab extends the cluster from clustering-01/02 by adding autofencing to Corosync. Autofencing tells the votequorum provider to automatically shut down nodes that lose quorum, preventing split-brain scenarios.

## Prerequisites
- Clustering-01 complete: 3-node Pacemaker/Corosync cluster with Apache managed resource
- Clustering-02 complete: STONITH enabled with fence devices configured

## What the Grader Checks

The grader verifies:
- Cluster running with all 3 nodes online
- `expected_votes: 3` in corosync.conf (already from clustering-01)
- `provider: corosync_votequorum` in corosync.conf (already from clustering-01)
- `ringnumber` in corosync.conf (already from clustering-01)
- `two_node: 0` in corosync.conf (already from clustering-01)
- **`autofencing` present in corosync.conf** ← new requirement
- STONITH still enabled
- No split-brain, managed resources running

## Step 1: Verify Existing Cluster State

```bash
# On Node 1
sudo crm_mon -1
# All 3 nodes should be Online

sudo pcs property config | grep stonith
# Should show stonith-enabled: true

sudo corosync-quorumtool
# Should show Expected votes: 3, Quorate: Yes
```

## Step 2: Add Autofencing to Corosync Configuration

Autofencing is a directive in the `quorum` block of corosync.conf. It must be added to all 3 nodes.

**From workstation**, update the quorum block on each node:

```bash
source /opt/linux-labs/lib/load-config.sh
load_lab_config
NODE1_IP=$(get_node_ip 1)
NODE2_IP=$(get_node_ip 2)
NODE3_IP=$(get_node_ip 3)

for node_ip in $NODE1_IP $NODE2_IP $NODE3_IP; do
    ssh opsadmin@$node_ip "sudo sed -i '/wait_for_all:/a\\    autofencing: 1' /etc/corosync/corosync.conf"
done
```

If `wait_for_all` is not in the file, use this alternative that adds before the closing `}` of the quorum block:

```bash
for node_ip in $NODE1_IP $NODE2_IP $NODE3_IP; do
    ssh opsadmin@$node_ip "sudo sed -i '/^quorum {/,/^}/{s/^}/    autofencing: 1\n}/}' /etc/corosync/corosync.conf"
done
```

Or edit the file manually on each node. The quorum block should look like:

```
quorum {
    provider: corosync_votequorum
    expected_votes: 3
    two_node: 0
    wait_for_all: 0
    autofencing: 1
}
```

## Step 3: Restart Corosync and Pacemaker on All Nodes

Restart services to pick up the new corosync.conf. Do this rolling — one node at a time to avoid quorum loss:

```bash
# Restart Node 1 first
ssh opsadmin@$NODE1_IP "sudo systemctl restart corosync pacemaker"
sleep 15

# Then Node 2
ssh opsadmin@$NODE2_IP "sudo systemctl restart corosync pacemaker"
sleep 15

# Then Node 3
ssh opsadmin@$NODE3_IP "sudo systemctl restart corosync pacemaker"
sleep 15
```

## Step 4: Verify Configuration Applied

```bash
# Verify autofencing is in the config
ssh opsadmin@$NODE1_IP "sudo grep autofencing /etc/corosync/corosync.conf"
# Should output: autofencing: 1

# Verify cluster is healthy
ssh opsadmin@$NODE1_IP "sudo crm_mon -1"
# Should show all 3 nodes Online and apache_web Started
```

## Verify

```bash
sudo labctl grade clustering-03
```

## Troubleshooting

**Cluster loses quorum after restarting corosync:**
```bash
# If a node doesn't come back, restart services manually
ssh opsadmin@$NODE_IP "sudo systemctl restart corosync pacemaker"
# Wait 15-20 seconds for cluster to reform
```

**Autofencing check fails but the line is in the file:**
```bash
# Verify grep finds it
ssh opsadmin@$NODE1_IP "sudo grep -i 'autofencing' /etc/corosync/corosync.conf"
```

**corosync fails to start after edit:**
```bash
# Check for parse errors
ssh opsadmin@$NODE1_IP "sudo corosync -f 2>&1 | head -20"
```

**Apache stops after restart:**
```bash
ssh opsadmin@$NODE1_IP "sudo pcs resource cleanup apache_web"
```

## How Autofencing Works

With `autofencing: 1` in the quorum block, Corosync's votequorum module will automatically kill (fence) nodes that are in a minority partition. This complements STONITH:
- **STONITH**: Pacemaker explicitly fences a node after detecting it failed
- **Autofencing**: Corosync votequorum fences nodes in minority partitions before Pacemaker acts
