# Static Node IP Address Configuration - Examples

## Overview

You can now configure static IP addresses for multi-node labs instead of using auto-calculated IPs from the network CIDR.

## Use Cases

### 1. Existing VM Infrastructure
You already have VMs with fixed IPs:
```bash
sudo labctl configure set NODE_IPS "192.168.1.101 192.168.1.102 192.168.1.103"
```

### 2. Non-Contiguous IP Addresses
Your nodes don't follow a sequential pattern:
```bash
sudo labctl configure set NODE_IPS "10.0.0.5 10.0.0.17 10.0.0.23"
```

### 3. Different Subnets
Nodes are in different networks:
```bash
sudo labctl configure set NODE_IPS "172.16.0.10 192.168.50.20 10.0.0.30"
```

### 4. Cloud Instances
Using cloud provider assigned IPs:
```bash
sudo labctl configure set NODE_IPS "203.0.113.10 203.0.113.20 203.0.113.30"
```

## Configuration Methods

### Method 1: Interactive Wizard

```bash
$ sudo labctl configure interactive
======================================
Linux Labs Configuration Wizard
======================================

Current settings:
  Lab Network: 192.168.100.0/24
  Gateway: 192.168.100.1
  DNS: 8.8.8.8
  Multi-node: false
  Node IPs: auto-calculated

Enable multi-node labs? (y/n) [n]: y
Number of nodes? [3]: 3

Node IP Configuration:
  1. Auto-calculate from network (e.g., 192.168.100.11, .12, .13)
  2. Set static IP addresses
Choose option [1]: 2

Enter static IP addresses (space-separated):
IPs: 10.0.0.101 10.0.0.102 10.0.0.103
✓ Using 3 static IPs: 10.0.0.101 10.0.0.102 10.0.0.103

Lab network [192.168.100.0/24]: <enter>
Gateway IP [192.168.100.1]: <enter>
DNS server [8.8.8.8]: <enter>

✓ Configuration saved to ~/.config/linux-labs/config
```

### Method 2: Direct Configuration

```bash
# Enable multi-node
$ sudo labctl configure set NODES_ENABLED true

# Set static IPs
$ sudo labctl configure set NODE_IPS "10.50.0.10 10.50.0.20 10.50.0.30"

# Node count is auto-detected from number of IPs
$ labctl configure list
Current Lab Configuration:
==========================
Network: 192.168.100.0/24
Gateway: 192.168.100.1
DNS: 8.8.8.8
Multi-node enabled: true
Node count: 3
Node IPs (static): 10.50.0.10 10.50.0.20 10.50.0.30
SSH Key: /root/.ssh/id_rsa
SSH User: root
SSH Port: 22
Config file: ~/.config/linux-labs/config
```

### Method 3: Manual Config File Edit

Edit `~/.config/linux-labs/config`:
```bash
# Linux Labs Configuration
LAB_NETWORK="192.168.100.0/24"
LAB_GATEWAY="192.168.100.1"
LAB_DNS="8.8.8.8"
NODES_ENABLED=true
NODE_COUNT=3
NODE_IPS="172.16.0.10 172.16.0.20 172.16.0.30"
SSH_KEY_PATH="$HOME/.ssh/id_rsa"
SSH_USER="root"
SSH_PORT="22"
DOCKER_ENABLED=false
```

## Behavior in Lab Scripts

When `NODE_IPS` is set, lab scripts automatically use your static IPs:

```bash
# In any lab script
source /opt/linux-labs/lib/load-config.sh

# Get individual node IPs
MASTER_IP=$(get_node_ip 1)    # Returns 10.0.0.101 (from NODE_IPS)
SLAVE_IP=$(get_node_ip 2)     # Returns 10.0.0.102

# Get all node IPs
ALL_IPS=$(get_all_node_ips)   # Returns "10.0.0.101 10.0.0.102 10.0.0.103"

# Loop through all nodes
for node_ip in $(get_all_node_ips); do
    run_on_node "$node_ip" "systemctl status mysql"
done
```

## Switching Between Auto and Static

### From Auto to Static:
```bash
$ sudo labctl configure set NODE_IPS "10.0.0.5 10.0.0.6 10.0.0.7"
```

### From Static back to Auto:
```bash
$ sudo labctl configure set NODE_IPS ""
```

Empty `NODE_IPS` makes the system auto-calculate IPs from `LAB_NETWORK`.

## Validation

The system validates configuration but doesn't verify IPs are reachable:

```bash
$ labctl configure validate
Validating configuration...
✓ Network format valid
✓ Gateway IP valid
✓ DNS IP valid
✓ All validations passed
```

To test node connectivity:
```bash
# Test in a lab script or manually
source /opt/linux-labs/lib/load-config.sh

for node_ip in $(get_all_node_ips); do
    if test_node_connectivity "$node_ip"; then
        echo "✓ Node $node_ip is reachable"
    else
        echo "✗ Node $node_ip is NOT reachable"
    fi
done
```

## Example: Replication Lab with Static IPs

```bash
# Configure static IPs for existing database servers
$ sudo labctl configure set NODES_ENABLED true
$ sudo labctl configure set NODE_IPS "192.168.1.10 192.168.1.20"

# Start the lab
$ sudo labctl start replication-01

# The lab automatically uses your IPs:
# Master: 192.168.1.10
# Slave: 192.168.1.20

# Grade the lab
$ labctl grade replication-01
1. Checking master MySQL service... PASS
2. Checking slave MySQL service... PASS
...
```

## Tips

1. **IP Count Must Match NODE_COUNT**: When using interactive wizard option 2, NODE_COUNT is automatically set to match the number of IPs provided.

2. **No IP Format Validation**: The system doesn't validate individual IPs in NODE_IPS. Ensure they're valid IPv4 addresses.

3. **Space-Separated Only**: Use spaces to separate IPs, not commas or newlines:
   - ✓ Good: `"10.0.0.1 10.0.0.2 10.0.0.3"`
   - ✗ Bad: `"10.0.0.1,10.0.0.2,10.0.0.3"`

4. **SSH Access Required**: Static IPs still need SSH access configured. Ensure:
   - SSH keys are set up
   - SSH_USER has access to all nodes
   - Firewall rules allow SSH

5. **Environment Override**: You can override config file values via environment variables:
   ```bash
   export NODE_IPS="different.ip.set 10.0.0.5"
   labctl start replication-01
   ```

## Troubleshooting

### Static IPs not being used
Check configuration:
```bash
$ labctl configure list | grep "Node IPs"
Node IPs (static): 10.0.0.101 10.0.0.102 10.0.0.103
```

If it says "auto-calculated", NODE_IPS is empty. Set it again:
```bash
$ sudo labctl configure set NODE_IPS "your ips here"
```

### Can't SSH to static IPs
Verify connectivity manually:
```bash
$ ssh -i ~/.ssh/id_rsa root@10.0.0.101 "echo test"
```

Check SSH configuration:
```bash
$ labctl configure list | grep SSH
SSH Key: /root/.ssh/id_rsa
SSH User: root
SSH Port: 22
```

### Wrong number of IPs
The interactive wizard auto-sets NODE_COUNT. If you manually set NODE_IPS, update NODE_COUNT too:
```bash
$ sudo labctl configure set NODE_IPS "ip1 ip2 ip3 ip4"
$ sudo labctl configure set NODE_COUNT 4
```
