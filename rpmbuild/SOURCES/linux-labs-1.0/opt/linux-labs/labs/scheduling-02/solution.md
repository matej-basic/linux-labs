# Scheduling Lab 02: Systemd Timers - Solution

## Overview
This lab demonstrates how to create and manage systemd timer units that run scripts at regular intervals, replacing traditional cron jobs with the more modern systemd approach.

## Solution Steps

### Step 1: Create the Service File
Create `/etc/systemd/system/lab-task.service`:

```bash
sudo tee /etc/systemd/system/lab-task.service > /dev/null <<'EOF'
[Unit]
Description=Lab Task Service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/lab-task.sh
EOF
```

**Key Points:**
- `Type=oneshot`: Runs once and exits
- `ExecStart`: Path to the script to execute

### Step 2: Create the Timer File
Create `/etc/systemd/system/lab-task.timer`:

```bash
sudo tee /etc/systemd/system/lab-task.timer > /dev/null <<'EOF'
[Unit]
Description=Lab Task Timer

[Timer]
OnBootSec=1min
OnUnitActiveSec=10min

[Install]
WantedBy=timers.target
EOF
```

**Key Points:**
- `OnBootSec=1min`: Run 1 minute after boot
- `OnUnitActiveSec=10min`: Run every 10 minutes after the service last executed
- `WantedBy=timers.target`: Enable the timer at boot

### Step 3: Create the Script
Create `/usr/local/bin/lab-task.sh`:

```bash
sudo tee /usr/local/bin/lab-task.sh > /dev/null <<'EOF'
#!/bin/bash
echo "Lab task executed at $(date)" >> /var/log/lab-task.log
EOF
```

Make it executable:

```bash
sudo chmod +x /usr/local/bin/lab-task.sh
```

### Step 4: Enable and Start the Timer

```bash
# Reload systemd to recognize new files
sudo systemctl daemon-reload

# Enable the timer to start at boot
sudo systemctl enable lab-task.timer

# Start the timer immediately
sudo systemctl start lab-task.timer
```

## Verification

Check that the timer is running:

```bash
# List active timers
sudo systemctl list-timers lab-task.timer

# Check timer status
sudo systemctl status lab-task.timer

# Check service status
sudo systemctl status lab-task.service

# View the log after it executes
sudo tail /var/log/lab-task.log
```

## Key Concepts

### Systemd Timers vs Cron
- **Systemd Timers:** Run with specific privileges, can use dependencies, easier logging to journalctl
- **Cron:** Traditional, but less flexible with modern systemd-based systems

### Timer Types
- `OnBootSec`: Time after system boot
- `OnUnitActiveSec`: Time since last execution
- `OnCalendar`: Specific dates/times (like cron syntax)

### Service Types
- `Type=oneshot`: Run once and exit
- `Type=simple`: Start and stay running
- `Type=forking`: Traditional fork/daemonize approach

## Troubleshooting

**Timer not running:**
```bash
# Check timer is enabled
sudo systemctl is-enabled lab-task.timer

# Check service status
sudo systemctl status lab-task.service

# View recent logs
sudo journalctl -u lab-task.timer -n 20
sudo journalctl -u lab-task.service -n 20
```

**Script not executing:**
```bash
# Verify script is executable
ls -l /usr/local/bin/lab-task.sh

# Test script manually
sudo bash /usr/local/bin/lab-task.sh

# Check journalctl for errors
sudo journalctl -xe
```

## Useful Commands

```bash
# View all active timers
sudo systemctl list-timers

# View timer schedule
sudo systemctl status lab-task.timer

# Stop the timer
sudo systemctl stop lab-task.timer

# Disable the timer (won't start at boot)
sudo systemctl disable lab-task.timer

# View timer logs
sudo journalctl -u lab-task.timer --follow
```
