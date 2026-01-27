# labctl Quick Reference

## Basic Lab Commands

```bash
# List all available labs
labctl list

# Start a lab (requires sudo)
sudo labctl start files-01

# Grade your work (automatic validation)
labctl grade files-01

# See the solution
labctl solution files-01

# Clean up and reset (requires sudo)
sudo labctl reset files-01
```

## Configuration Management

```bash
# Interactive configuration wizard
sudo labctl configure interactive

# View current configuration
labctl configure list

# Update a specific setting
labctl configure set NODE_COUNT 3
labctl configure set LAB_DNS 192.168.100.1

# Validate your configuration
labctl configure validate

# Reset to defaults
sudo labctl configure reset
```

## Multi-Node Lab Setup

```bash
# 1. Enable multi-node labs
sudo labctl configure interactive
# Answer: y for multi-node labs
# Enter: number of nodes (e.g., 3)
# Configure network and DNS

# 2. Verify configuration
labctl configure list

# 3. Labs will automatically use the configuration
sudo labctl start database-replication-01  # (when available)
```

## Configuration Options

| Option | Default | Purpose |
|--------|---------|---------|
| LAB_NETWORK | 192.168.100.0/24 | Lab subnet (CIDR notation) |
| LAB_GATEWAY | 192.168.100.1 | Network gateway IP |
| LAB_DNS | 8.8.8.8 | DNS server for labs |
| NODES_ENABLED | false | Enable multi-node labs |
| NODE_COUNT | 1 | Number of nodes (if enabled) |
| SSH_KEY_PATH | ~/.ssh/id_rsa | SSH key for remote nodes |
| SSH_USER | root | SSH user for nodes |
| SSH_PORT | 22 | SSH port for nodes |

## Configuration File Locations

1. System-wide: `/etc/linux-labs/config` (system admin)
2. User-specific: `~/.config/linux-labs/config` (your user)
3. Template: `/etc/linux-labs/config.template` (reference)

## Common Tasks

### Viewing Lab Content
```bash
# Read lab objective
cat labs/webserver-01/description.txt

# See step-by-step solution
labctl solution webserver-01 | less
```

### Working Through a Lab
```bash
# Start lab (need sudo)
sudo labctl start webserver-01

# Your terminal will show:
# [webserver-01] $ bash prompt

# Complete the tasks as described in description.txt

# Check your progress
labctl grade webserver-01

# View solution if stuck
labctl solution webserver-01
```

### Multi-Node Lab (Future)
```bash
# Setup multi-node environment
sudo labctl configure interactive

# Complete the multi-node lab
sudo labctl start database-cluster-01

# Grade multi-node lab
labctl grade database-cluster-01

# See how it was done
labctl solution database-cluster-01
```

## Examples by Lab Category

### Getting Started (File System)
```bash
sudo labctl start files-01     # Basic file operations
sudo labctl start files-02     # Permissions
sudo labctl start files-03     # Find and grep
```

### Users and Permissions
```bash
sudo labctl start users-01     # User management
sudo labctl start users-02     # File permissions
sudo labctl start users-03     # Sudo privileges
```

### Networking
```bash
sudo labctl start networking-01  # Interface configuration
sudo labctl start networking-02  # DNS configuration
sudo labctl start networking-03  # Troubleshooting
```

### Web Servers
```bash
sudo labctl start webserver-01   # Apache basics
sudo labctl start webserver-02   # Virtual hosts
sudo labctl start webserver-03   # HTTPS/SSL
```

### Databases
```bash
sudo labctl start mysql-01       # MySQL basics
sudo labctl start postgres-01    # PostgreSQL basics
```

### DNS (Advanced)
```bash
sudo labctl start dns-01         # BIND installation
sudo labctl start dns-02         # Zone configuration
sudo labctl start dns-03         # DNSSEC signing
```

## Troubleshooting

### "Unknown lab" error
```bash
# Check lab name
labctl list

# Verify lab exists
ls labs/files-01/
```

### "Permission denied" for start/reset
```bash
# These commands require root
sudo labctl start files-01
sudo labctl reset files-01
```

### Configuration not loading
```bash
# Check configuration exists
cat ~/.config/linux-labs/config

# Reset to defaults
labctl configure reset

# Create default if missing
labctl configure list
```

### Lab not grading properly
```bash
# Run setup first
sudo labctl start labs-name

# Then grade
labctl grade labs-name

# See the solution
labctl solution labs-name
```

## Tips and Tricks

1. **Tab completion**: After installation, use Tab to complete lab names
2. **Less pager**: Solutions open in `less` for easier navigation
3. **Config file**: Edit `~/.config/linux-labs/config` directly for bulk changes
4. **Multi-lab testing**: Can run multiple labs in different terminals
5. **Log checking**: Most labs write to syslog, check with `journalctl`

## More Information

- Full documentation: See [README.md](README.md)
- Configuration guide: See [CONFIGURE_SYSTEM.md](CONFIGURE_SYSTEM.md)
- Lab roadmap: See [LAB_IDEAS.md](LAB_IDEAS.md)
- Report issues: Open an issue in the repository
