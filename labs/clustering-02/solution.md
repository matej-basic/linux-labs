# Clustering 02 Solution - STONITH Fencing Configuration

## Overview
This lab adds STONITH (Shoot The Other Node In The Head) fencing to the cluster built in clustering-01. STONITH prevents split-brain by ensuring a failed node is powered off before resources are migrated.

## Prerequisites
Clustering-01 must be complete: Pacemaker/Corosync running on all 3 nodes, Apache managed as a Pacemaker resource, `stonith-enabled=false` set.

## Step 1: Install Fence Agents on All Nodes

```bash
# On all 3 nodes (servera, serverb, serverc)
sudo dnf install -y --enablerepo=ha fence-agents-all
```

## Step 2: Re-Enable STONITH in Pacemaker

Clustering-01 disabled STONITH. Now that fence devices will be configured, re-enable it:

```bash
# On Node 1
sudo pcs property set stonith-enabled=true
```

## Step 3: Create STONITH Devices for Each Node

```bash
# Get node IPs
source /opt/linux-labs/lib/load-config.sh
load_lab_config
NODE1_IP=$(get_node_ip 1)
NODE2_IP=$(get_node_ip 2)
NODE3_IP=$(get_node_ip 3)

# Create one STONITH device per node using fence_virsh
# migration-threshold=INFINITY prevents Pacemaker from cleaning up
# the device when it fails (expected in a lab with no real hypervisor)
sudo pcs stonith create stonith-node1 fence_virsh \
  ipaddr=127.0.0.1 login=root \
  pcmk_host_list=servera \
  meta migration-threshold=INFINITY

sudo pcs stonith create stonith-node2 fence_virsh \
  ipaddr=127.0.0.1 login=root \
  pcmk_host_list=serverb \
  meta migration-threshold=INFINITY

sudo pcs stonith create stonith-node3 fence_virsh \
  ipaddr=127.0.0.1 login=root \
  pcmk_host_list=serverc \
  meta migration-threshold=INFINITY
```

**Note**: In this lab environment `fence_virsh` cannot reach a real hypervisor, so the devices will fail when tested. The `meta migration-threshold=INFINITY` prevents this from blocking Apache. In production, use IPMI (`fence_ipmilan`), AWS (`fence_aws`), or a real KVM hypervisor.

**Important**: In pcs 0.10+, STONITH resources are managed separately from regular resources. Use `pcs stonith` subcommands — NOT `pcs resource` — to create, delete, or list fence devices.

## Step 4: Verify STONITH Configuration

```bash
# View STONITH resources (NOT pcs resource config)
sudo pcs stonith config
# Should show 3 resources: stonith-node1, stonith-node2, stonith-node3

# Verify STONITH is enabled
sudo pcs property config | grep stonith
# Should show: stonith-enabled: true
```

## Step 5: Verify Apache Resource Still Running

```bash
sudo crm_mon -1
# Should show apache_web as Started on one of the nodes

sudo pcs resource status
```

## Verify

```bash
sudo labctl grade clustering-02
```

## Troubleshooting

**STONITH devices show as Failed or cleaned up:**
```bash
# Re-add with migration-threshold=INFINITY if cleaned up
sudo pcs stonith create stonith-node1 fence_virsh \
  ipaddr=127.0.0.1 login=root pcmk_host_list=servera \
  meta migration-threshold=INFINITY
```

**Apache stops after enabling STONITH:**
```bash
sudo pcs resource cleanup apache_web
# Wait 30 seconds for Pacemaker to restart it
```

**pcs stonith config shows nothing but pcs resource config is empty too:**
STONITH resources only appear in `pcs stonith config`. Check there specifically.

**fence_virsh not found:**
```bash
sudo dnf install -y --enablerepo=ha fence-agents-all
```
