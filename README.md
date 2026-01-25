# Linux Labs

A comprehensive collection of hands-on Linux lab exercises covering essential system administration topics.

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
│   └── ... (39 labs total)
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
├── scripts/                 # Build automation
│   └── build-rpm-linux.sh   # Script to build the RPM package
├── README.md                # This file
├── LAB_IDEAS.md            # Comprehensive lab roadmap
└── .gitignore              # Git configuration

# Local directories (created during build, not in git)
packaging/
└── rpmbuild/               # RPM build system (created by build script)
    ├── SOURCES/
    ├── SPECS/
    ├── BUILD/              # Build artifacts
    ├── BUILDROOT/          # Installation root
    ├── RPMS/               # Built RPM packages
    └── SRPMS/              # Source RPM packages
```

## Building the RPM Package

To create an installable RPM package:

```bash
cd scripts/
./build-rpm-linux.sh
```

This script will:
1. Sync labs, configuration files, and binaries from the root source directories to the packaging build directory
2. Create a source tarball with all lab content and system files
3. Build the RPM using rpmbuild
4. Place the finished RPM in `packaging/rpmbuild/RPMS/noarch/`

**Important**: The build script performs these operations on each build:
- Deletes and re-syncs `labs/` → `packaging/rpmbuild/SOURCES/linux-labs-1.0/opt/linux-labs/labs/`
- Deletes and re-syncs `src/etc/` → `packaging/rpmbuild/SOURCES/linux-labs-1.0/etc/`
- Deletes and re-syncs `src/usr/` → `packaging/rpmbuild/SOURCES/linux-labs-1.0/usr/`

This ensures all changes to `labs/`, `src/etc/`, and `src/usr/` are included in the RPM.

**Note**: The `packaging/` directory is local-only and not tracked in git. For development, work directly in the root `labs/` and `src/` directories and the build script will pick up changes automatically on the next build.

## Installation

To install the labs on a target system:

```bash
# Install from RPM
dnf install linux-labs-1.0-1.el8.noarch.rpm

# Labs will be installed to /opt/linux-labs/
# The labctl tool will be available in your PATH
```

## Requirements

- Rocky Linux 8, RHEL 8, or compatible system
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
