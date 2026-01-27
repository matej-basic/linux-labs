# Linux Labs Configuration System

## Overview

The Linux Labs configuration system enables users to customize their lab environment, particularly for advanced multi-node lab scenarios. The system provides an interactive configuration wizard, validation tools, and helper libraries for lab scripts.

## Components

### 1. Enhanced labctl Binary (`src/usr/bin/labctl`)

The main `labctl` command now includes a `configure` subcommand with the following actions:

#### Interactive Configuration
```bash
labctl configure interactive
```
Opens an interactive wizard to configure:
- Multi-node lab enablement (yes/no)
- Number of nodes (if enabled)
- Lab network (CIDR notation)
- Gateway IP
- DNS server

#### View Configuration
```bash
labctl configure list
```
Displays all current configuration settings and their values.

#### Set Individual Values
```bash
labctl configure set KEY VALUE
```
Updates a specific configuration parameter.

Examples:
```bash
labctl configure set NODE_COUNT 5
labctl configure set LAB_DNS 192.168.100.1
```

#### Validate Configuration
```bash
labctl configure validate
```
Checks configuration for validity:
- Network format (CIDR notation)
- IP address format
- All required fields present

#### Reset to Defaults
```bash
labctl configure reset
```
Resets all configuration to factory defaults.

### 2. Configuration File Locations

Configuration is stored at:

1. **System-wide** (highest priority): `/etc/linux-labs/config`
2. **User-specific**: `~/.config/linux-labs/config`
3. **Built-in defaults** (lowest priority): Hardcoded in scripts

The first file found (in order above) is used. System configuration takes precedence over user configuration.

### 3. Configuration Template (`src/etc/linux-labs/config.template`)

A template configuration file showing all available options with documentation:

```bash
LAB_NETWORK="192.168.100.0/24"    # Lab subnet (CIDR)
LAB_GATEWAY="192.168.100.1"        # Default gateway
LAB_DNS="8.8.8.8"                  # DNS server
NODES_ENABLED="false"              # Multi-node enablement
NODE_COUNT="1"                     # Number of nodes
NODE_IPS=""                        # Static node IPs (optional, space-separated)
SSH_KEY_PATH="$HOME/.ssh/id_rsa"   # SSH private key path
SSH_USER="root"                    # SSH user for nodes
SSH_PORT="22"                      # SSH port
DOCKER_ENABLED="false"             # Docker enablement
```

**NODE_IPS Configuration:**
- Leave empty (`NODE_IPS=""`) to auto-calculate IPs from LAB_NETWORK
- Set to space-separated IPs for static addresses (e.g., `NODE_IPS="10.0.0.5 10.0.0.6 10.0.0.7"`)
- If set, overrides LAB_NETWORK for node IP calculation
- NODE_COUNT should match the number of IPs provided

### 4. Configuration Helper Library (`src/opt/linux-labs/lib/load-config.sh`)

A bash library for lab scripts to load and use configuration. Source it in your lab scripts:

```bash
source /opt/linux-labs/lib/load-config.sh
```

#### Available Functions

**load_lab_config()**
- Loads configuration from file
- Sets environment variables
- Applies defaults for unset values
- Exports all variables for child processes

**get_node_ip(node_num)**
- Returns the IP address for a specific node
- If NODE_IPS is set, returns the nth IP from the list
- Otherwise, calculates IP from LAB_NETWORK
- Example: `get_node_ip 1` returns `192.168.100.11` (auto) or first IP from NODE_IPS

**get_all_node_ips()**
- Returns space-separated list of all node IPs
- If NODE_IPS is set, returns those IPs
- Otherwise, calculates all IPs from LAB_NETWORK
- Useful for looping or passing to other tools

**test_node_connectivity(ip)**
- Tests SSH connectivity to a remote node
- Returns 0 if connected, 1 if not
- Non-blocking (2-second timeout)

**run_on_node(ip, command)**
- Executes a command on a remote node via SSH
- Respects SSH_KEY_PATH, SSH_USER, SSH_PORT settings

**wait_for_node(ip, max_attempts)**
- Blocks until SSH connection succeeds or timeout
- Default: 30 attempts (30 seconds)

#### Example Usage

```bash
#!/bin/bash
source /opt/linux-labs/lib/load-config.sh

# Display current configuration
echo "Lab Network: $LAB_NETWORK"
echo "Nodes enabled: $NODES_ENABLED"
echo "Node count: $NODE_COUNT"

# For multi-node labs
if [[ "$NODES_ENABLED" == "true" ]]; then
    # Get all node IPs
    for node_ip in $(get_all_node_ips); do
        echo "Node: $node_ip"
        
        # Wait for node to be ready
        if wait_for_node "$node_ip" 30; then
            # Run commands on the node
            run_on_node "$node_ip" "systemctl status httpd"
        else
            echo "Node $node_ip not reachable"
        fi
    done
fi
```

## Configuration Workflow

### For Single-Node Labs (Default)

No configuration needed! Labs use defaults:
- Network: 192.168.100.0/24
- Single node (NODE_COUNT=1)

### For Multi-Node Labs

1. Enable multi-node configuration:
```bash
sudo labctl configure interactive
# Answer: y for multi-node
# Enter: desired number of nodes (e.g., 3)
# Configure network and DNS as needed
```

2. View your configuration:
```bash
labctl configure list
```

3. Validate configuration:
```bash
labctl configure validate
```

4. Labs automatically use this configuration when they source the load-config.sh library

### Network Address Assignment

You can choose between **automatic IP calculation** or **static IP addresses**.

#### Option 1: Auto-Calculated IPs (Default)

When NODES_ENABLED=true and NODE_IPS is empty, node IPs are automatically calculated:

```
Base network: 192.168.100.0/24
Node 1: 192.168.100.11
Node 2: 192.168.100.12
Node 3: 192.168.100.13
...
Node N: 192.168.100.(10+N)
```

Example with custom network:
```
Base network: 10.0.0.0/24
Node 1: 10.0.0.11
Node 2: 10.0.0.12
Node 3: 10.0.0.13
```

#### Option 2: Static IP Addresses

For existing VMs or containers with specific IPs, set NODE_IPS:

```bash
# Interactive wizard (choose option 2)
sudo labctl configure interactive

# Or set directly
sudo labctl configure set NODE_IPS "192.168.1.10 192.168.1.20 192.168.1.30"
```

Example configuration with static IPs:
```bash
NODES_ENABLED=true
NODE_COUNT=3
NODE_IPS="10.0.0.101 10.0.0.102 10.0.0.103"
```

When NODE_IPS is set:
- `get_node_ip(1)` returns `10.0.0.101`
- `get_node_ip(2)` returns `10.0.0.102`
- `get_all_node_ips()` returns `10.0.0.101 10.0.0.102 10.0.0.103`

Static IPs are useful for:
- Existing VM infrastructure with predefined IPs
- Non-contiguous IP addresses
- Different subnets for different nodes
- Integration with external DHCP or IP management

## Configuration Persistence

- Configuration is stored in `~/.config/linux-labs/config` (user-specific)
- System administrators can set `/etc/linux-labs/config` for all users
- Configuration persists across lab resets and system reboots
- Use `labctl configure reset` to restore factory defaults

## Security Considerations

1. **SSH Keys**: Ensure SSH key path is correct and has proper permissions (600)
2. **SSH User**: Defaults to root; change if non-root access is needed
3. **Network**: Choose appropriate CIDR ranges that don't conflict with your network
4. **DNS**: Ensure configured DNS server is reachable and functional

## Building and Installation

The configuration system is built into the Linux Labs RPM:

```bash
cd scripts/
./build-rpm-linux.sh

# Install the RPM
dnf install packaging/rpmbuild/RPMS/noarch/linux-labs-1.0-1.el8.noarch.rpm
```

On installation, the configuration files are placed at:
- `/opt/linux-labs/lib/load-config.sh` - Helper library
- `/etc/linux-labs/config.template` - Template configuration
- Updated `/usr/bin/labctl` - Enhanced labctl binary

## Future Multi-Node Labs

Future labs can leverage this configuration system to:

- **Database Replication**: MySQL master-slave, PostgreSQL streaming replication
- **High Availability**: PostgreSQL with Patroni, MySQL with Percona XtraDB Cluster
- **Clustering**: Kubernetes on multiple nodes, GlusterFS storage clusters
- **Load Balancing**: HAProxy, nginx load balancer across multiple backend nodes
- **Distributed Databases**: Cassandra clusters, MongoDB replicas

These labs will:
1. Source `/opt/linux-labs/lib/load-config.sh`
2. Use configuration values for node setup and validation
3. Support automatic node discovery and provisioning
4. Enable SSH-based multi-node operations

## Troubleshooting

### Configuration not loading
```bash
# Check file exists and is readable
ls -la ~/.config/linux-labs/config
cat ~/.config/linux-labs/config

# Check system configuration
sudo cat /etc/linux-labs/config
```

### Validation fails
```bash
# Validate current configuration
labctl configure validate

# Reset to working defaults
labctl configure reset
```

### Can't connect to nodes
```bash
# Check SSH configuration
labctl configure list | grep SSH

# Test SSH connectivity manually
ssh -i ~/.ssh/id_rsa root@192.168.100.11 "echo OK"

# Verify node is running and reachable
ping 192.168.100.11
```

### Multi-node labs not working
```bash
# Enable multi-node configuration
labctl configure interactive

# Verify multi-node is enabled
labctl configure list | grep -i "multi-node"

# Test helper library
bash -c 'source /opt/linux-labs/lib/load-config.sh && get_all_node_ips'
```

## Testing the System

Quick validation:

```bash
# List current configuration
labctl configure list

# Validate configuration syntax
labctl configure validate

# Set a test value
labctl configure set LAB_DNS 1.1.1.1

# Verify it was set
labctl configure list | grep DNS

# Reset to defaults
labctl configure reset

# Verify reset
labctl configure list | grep DNS
```

## Integration with Lab Scripts

To use the configuration system in a lab script:

```bash
#!/bin/bash
# setup.sh or solution.md for a multi-node lab

# Load configuration
if [ -f /opt/linux-labs/lib/load-config.sh ]; then
    source /opt/linux-labs/lib/load-config.sh
    
    # Use configuration
    echo "Setting up lab with $NODE_COUNT nodes"
    
    if [[ "$NODES_ENABLED" == "true" ]]; then
        for node_ip in $(get_all_node_ips); do
            echo "Configuring node: $node_ip"
            # Node-specific setup commands
        done
    fi
fi
```

## Configuration API Reference

### Environment Variables

After sourcing `/opt/linux-labs/lib/load-config.sh`:

```bash
$LAB_NETWORK       # Lab subnet (CIDR)
$LAB_GATEWAY       # Default gateway
$LAB_DNS           # DNS server
$NODES_ENABLED     # Multi-node enabled (true/false)
$NODE_COUNT        # Number of nodes
$SSH_KEY_PATH      # SSH private key path
$SSH_USER          # SSH user
$SSH_PORT          # SSH port
$DOCKER_ENABLED    # Docker enabled (true/false)
$CONFIG_FILE       # Path to loaded config file
```

### Functions

```bash
load_lab_config()              # Load and apply configuration
get_node_ip(num)               # Get IP for node N
get_all_node_ips()             # Get space-separated list of all node IPs
test_node_connectivity(ip)     # Test SSH to node (non-blocking)
run_on_node(ip, cmd)           # Execute command on remote node
wait_for_node(ip, max_attempts) # Block until node is ready
```

## Version History

- **v1.0** (Initial Release)
  - Configuration system with interactive wizard
  - Validation and configuration management
  - Multi-node lab support infrastructure
  - Helper library for lab scripts
  - SSH-based remote execution support
