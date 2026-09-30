# Linux Labs

A comprehensive collection of hands-on Linux lab exercises covering essential system administration topics.

**New in v1.0**: Interactive configuration system for multi-node lab support! See [QUICKSTART.md](QUICKSTART.md) or [CONFIGURE_SYSTEM.md](CONFIGURE_SYSTEM.md).

## Quick Start

Browse available labs in the [`labs/`](labs/) directory. Each lab contains:
- `description.txt` - Lab objectives and requirements
- `setup.sh` - Initialize the lab environment
- `grade.sh` - Automated grading/validation script
- `cleanup.sh` - Clean up after the lab
- `solution.md` - Step-by-step solution guide

### Example: Running a Lab

```bash
# Navigate to a specific lab
cd labs/files-01/

# Read the description
cat description.txt

# Set up the lab environment
bash setup.sh

# Work through the exercises...

# Check your progress
bash grade.sh

# Clean up when done
bash cleanup.sh
```

## Lab Categories

### 📁 File System (3 labs)
- **files-01** - Basic file operations (create, edit, delete)
- **files-02** - File permissions and ownership
- **files-03** - Find and grep commands

### 🔒 Users & Permissions (3 labs)
- **users-01** - User and group creation
- **users-02** - File permissions (rwx)
- **users-03** - sudo and elevated privileges

### 📦 Package Management (3 labs)
- **packages-01** - Installing and removing packages
- **packages-02** - Updating systems and dependencies
- **packages-03** - Repository management

### 🌐 Networking (3 labs)
- **networking-01** - Network interfaces and IP configuration
- **networking-02** - DNS and hostname resolution
- **networking-03** - Network connectivity and troubleshooting

### 🔥 Firewall (3 labs)
- **firewall-01** - firewalld basics and zones
- **firewall-02** - Service and port management
- **firewall-03** - Advanced firewall rules

### 📊 System Logging (3 labs)
- **logging-01** - systemd journal basics
- **logging-02** - Log filtering and analysis
- **logging-03** - Log rotation and retention

### ⏰ Task Scheduling (3 labs)
- **scheduling-01** - cron basics and crontab
- **scheduling-02** - at and anacron scheduling
- **scheduling-03** - Systemd timers

### 🔐 SELinux (3 labs)
- **selinux-01** - SELinux modes and contexts
- **selinux-02** - Boolean settings and policies
- **selinux-03** - Troubleshooting SELinux issues

### 💾 Storage (3 labs)
- **storage-01** - Partition creation and management
- **storage-02** - Logical volumes (LVM)
- **storage-03** - Mount points and fstab

### 🚀 Systemd (3 labs)
- **systemd-01** - Unit files and service management
- **systemd-02** - Target units and system states
- **systemd-03** - Timer units and socket activation

### 🌐 Web Servers (3 labs)
- **webserver-01** - Apache httpd installation and basics
- **webserver-02** - Virtual hosts configuration
- **webserver-03** - HTTPS/SSL certificates

### 🗄️ MySQL (3 labs)
- **mysql-01** - Installation and basic setup
- **mysql-02** - Database and user management
- **mysql-03** - Backup and restore procedures

### 🐘 PostgreSQL (3 labs)
- **postgres-01** - Installation and initialization
- **postgres-02** - Role and database management
- **postgres-03** - Backup and recovery

### 🌍 DNS (3 labs)
- **dns-01** - BIND installation and service startup
- **dns-02** - Zone configuration with DNS records
- **dns-03** - DNSSEC configuration and zone signing

### 🔄 Database Replication (3 labs, multi-node)
- **replication-01** - MySQL master-slave replication
- **replication-02** - PostgreSQL streaming replication with WAL archiving
- **replication-03** - MySQL multi-master circular replication

### ⚖️ Load Balancing (3 labs, multi-node)
- **lb-01** - HAProxy load balancing across 3 web servers
- **lb-02** - Nginx reverse proxy with health checks
- **lb-03** - keepalived VIP with automatic failover

### 🖥️ HA Clustering (3 labs, multi-node)
- **clustering-01** - Pacemaker/Corosync cluster setup across 3 nodes
- **clustering-02** - STONITH fencing and failover
- **clustering-03** - Quorum and split-brain prevention

## Documentation

- **[QUICKSTART.md](QUICKSTART.md)** - Quick reference for common commands and workflows
- **[CONFIGURE_SYSTEM.md](CONFIGURE_SYSTEM.md)** - Complete guide to the configuration system
- **[LAB_IDEAS.md](LAB_IDEAS.md)** - Roadmap of planned labs (392+ labs in 30+ categories)

## Configuration System

The Linux Labs package includes a configuration system for advanced lab setups, particularly for multi-node labs and custom networking:

### Using labctl configure

Configure your lab environment interactively:

```bash
# Interactive configuration wizard
sudo labctl configure interactive

# View current configuration
labctl configure list

# Set a specific value
labctl configure set NODE_COUNT 3

# Validate your configuration
labctl configure validate

# Reset to defaults
sudo labctl configure reset
```

### Configuration Options

Configuration is stored in:
- `/etc/linux-labs/config` (system-wide, highest priority)
- `~/.config/linux-labs/config` (user-specific)

Key configuration parameters:

```bash
# Network Configuration
LAB_NETWORK="172.25.250.0/24"     # Lab subnet
LAB_GATEWAY="172.25.250.254"       # Default gateway
LAB_DNS="8.8.8.8"                  # DNS server

# Multi-node Lab Configuration
NODES_ENABLED="false"              # Enable multi-node labs
NODE_COUNT="1"                     # Number of nodes

# SSH Configuration (for multi-node labs)
SSH_KEY_PATH="$HOME/.ssh/id_rsa"   # SSH private key
SSH_USER="root"                    # SSH user
SSH_PORT="22"                      # SSH port
```

### Multi-node Labs

For future multi-node labs, enable the configuration system:

```bash
sudo labctl configure interactive
# Answer: y for multi-node labs
# Enter: 3 for three nodes
# Configure network and SSH settings as needed
```

Lab scripts can then source the configuration to access these settings:

```bash
source /opt/linux-labs/lib/load-config.sh

# Access configuration variables
echo "Network: $LAB_NETWORK"
echo "Nodes: $NODE_COUNT"

# Get node IPs
get_all_node_ips

# Test connectivity to a node
test_node_connectivity 192.168.100.11

# Execute commands on a node
run_on_node 192.168.100.11 "systemctl status httpd"
```

## Future Labs

See [LAB_IDEAS.md](LAB_IDEAS.md) for proposed labs in development, including:
- Docker and container management
- Kubernetes cluster administration
- Advanced networking (DNS, NFS, VPN)
- Security hardening and compliance
- Monitoring and observability
- Backup and disaster recovery
- And 100+ more labs covering enterprise Linux topics

## Project Structure

```
linux-labs/
├── labs/                    # All lab exercises (source of truth)
│   ├── files-01/
│   ├── mysql-01/
│   ├── postgres-01/
│   └── ... (51 labs total)
├── src/                     # System files (installed to /, git-tracked)
│   ├── etc/                 # Configuration files (installed to /etc)
│   │   ├── profile.d/
│   │   │   └── labctl.sh    # Shell profile hook
│   │   └── sudoers.d/
│   │       └── labctl       # Sudo configuration
│   └── usr/                 # User binaries and docs (installed to /usr)
│       ├── bin/
│       │   └── labctl       # Main lab control tool
│       └── share/
│           └── man/man1/
│               └── labctl.1 # Man page
├── rpm/
│   └── linux-labs.spec      # RPM spec (Version: is the release version)
├── scripts/                 # Build and release automation
│   ├── build-rpm-linux.sh   # Build the RPM (optionally deploy to a test VM)
│   ├── sign-rpm.sh          # Sign RPMs with the release key (used by CI)
│   └── update-pages.sh      # Refresh the dnf repo on gh-pages (used by CI)
├── pages/                   # index.html and .repo file for GitHub Pages
├── .github/workflows/
│   └── rpm.yml              # Build, smoke test, sign, release, publish
├── install.sh               # curl installer, served as /install on Pages
├── RPM-GPG-KEY-linux-labs   # Public key the RPMs are signed with
├── README.md                # This file
├── LAB_IDEAS.md            # Comprehensive lab roadmap
└── .gitignore              # Git configuration

# Local directories (created during build, not in git)
packaging/
└── rpmbuild/               # rpmbuild topdir (created by build script)
    ├── SOURCES/
    ├── SPECS/              # Copy of rpm/linux-labs.spec
    ├── BUILD/              # Build artifacts
    ├── BUILDROOT/          # Installation root
    ├── RPMS/               # Built RPM packages
    └── SRPMS/              # Source RPM packages
```

## Building the RPM package

The spec is `rpm/linux-labs.spec`. Build on a Rocky/RHEL 8 host or container with `rpm-build` and `sudo` installed (`sudo` provides `visudo`, which the spec's `%check` uses to validate the sudoers rule):

```bash
scripts/build-rpm-linux.sh
```

The script reads `Name:` and `Version:` from the spec, then:
1. Deletes and re-creates `packaging/rpmbuild/SOURCES/<name>-<version>/` from `labs/`, `src/etc/`, `src/usr/` and `src/opt/linux-labs/lib/`
2. Copies the spec to `packaging/rpmbuild/SPECS/`
3. Creates the source tarball and runs `rpmbuild`
4. Leaves the RPM in `packaging/rpmbuild/RPMS/noarch/`

`packaging/` is a local build directory and is not tracked in git. Edit `labs/`, `src/` and `rpm/linux-labs.spec`, never the copies under `packaging/`.

To install the fresh build on a test VM, add `--deploy`:

```bash
scripts/build-rpm-linux.sh --deploy root@10.0.0.149
```

This copies the RPM to `/root/` on that host with `scp`, then removes and reinstalls `linux-labs` there with `dnf`. Without `--deploy` the script does not contact any host.

The build targets EL8 and the result is one noarch RPM (`Release: 1`, no dist tag) that installs on both EL8 and EL9.

### CI and releases

`.github/workflows/rpm.yml` builds the RPM in a `rockylinux/rockylinux:8` container on every push to `main` and every pull request, then installs it on Rocky 8 and Rocky 9 and runs `labctl list`, checks that `/usr/bin/labctl` is mode 755 and runs `visudo -c`.

To release a new version:

1. Bump `Version:` in `rpm/linux-labs.spec` and add a `%changelog` entry.
2. Commit and push to `main`.
3. Tag and push the tag:

   ```bash
   git tag v1.2.0
   git push origin v1.2.0
   ```

On a `vX.Y.Z` tag the workflow also checks that the tag matches the spec `Version:` (and fails if not), signs the RPM with the release key (secrets `RPM_GPG_PRIVATE_KEY` and `RPM_GPG_PASSPHRASE`), installs the signed RPM on Rocky 9 with `gpgcheck=1`, creates a GitHub Release with the RPM attached, and adds the RPM to the dnf repository on the `gh-pages` branch, which GitHub Pages serves at https://matej-basic.github.io/linux-labs/.

## Installation

On Rocky Linux, RHEL or AlmaLinux 8 or 9:

```bash
curl -fsSL https://matej-basic.github.io/linux-labs/install | sudo bash
```

The installer adds the `linux-labs` dnf repository, imports the signing key and installs the package, or upgrades it if it is already installed. Other distributions and EL10 are rejected.

To do the same by hand:

```bash
sudo curl -fsSL -o /etc/yum.repos.d/linux-labs.repo https://matej-basic.github.io/linux-labs/linux-labs.repo
sudo rpm --import https://matej-basic.github.io/linux-labs/RPM-GPG-KEY-linux-labs
sudo dnf install linux-labs
```

Later versions arrive with `sudo dnf upgrade linux-labs`. Each release RPM is also attached to its [GitHub Release](https://github.com/matej-basic/linux-labs/releases).

Labs are installed to `/opt/linux-labs/` and `labctl` to `/usr/bin/labctl`. Start with `labctl list`.

## Requirements

- Rocky Linux, RHEL or AlmaLinux 8 or 9
- Bash shell
- Standard Linux utilities (grep, sed, awk, etc.)
- Root access for some labs
- Individual lab requirements noted in `description.txt`

## Contributing

To add new labs:

1. Create a new directory under `labs/` with the naming convention `category-##`
2. Add the five required files: `description.txt`, `setup.sh`, `grade.sh`, `cleanup.sh`, `solution.md`
3. Follow the established patterns for consistency
4. Update `LAB_IDEAS.md` when adding new labs

## License

MIT

## Support

For issues, questions, or lab improvements, please open an issue in the repository.
