# Scheduling Lab 03: Advanced Scheduling Methods - Solution

## Overview
This lab covers three advanced scheduling approaches: **Anacron** (for offline systems), **Systemd Persistent Timers** (modern Linux systems), and **Complex Cron with Environment Variables** (traditional with advanced features).

## Part 1: Anacron

### What is Anacron?
Anacron runs jobs **regardless of boot time** - ideal for systems that are not always on. Unlike cron, anacron checks if a job has run within its specified period.

### Step 1: Create the Anacron Script
Create `/usr/local/bin/anacron-task.sh`:

```bash
sudo tee /usr/local/bin/anacron-task.sh > /dev/null <<'EOF'
#!/bin/bash
echo "Anacron task executed at $(date)" >> /var/log/anacron-task.log
EOF
```

Make it executable:

```bash
sudo chmod +x /usr/local/bin/anacron-task.sh
```

### Step 2: Add to Anacrontab
Edit `/etc/anacrontab`:

```bash
sudo vi /etc/anacrontab
```

Add this line at the end:

```
1       5       anacron_lab     /usr/local/bin/anacron-task.sh
```

**Format Explanation:**
- `1`: Period in days (run once per day)
- `5`: Delay in minutes after boot
- `anacron_lab`: Job identifier (must be unique)
- `/usr/local/bin/anacron-task.sh`: Command to execute

### Verification
```bash
# Check anacron is running
sudo systemctl status anacron

# View anacron spool file (shows last run time)
sudo cat /var/spool/anacron/anacron_lab

# View anacron logs
sudo grep anacron /var/log/cron
# or
sudo journalctl -u anacron
```

## Part 2: Systemd Persistent Timer

### What is Persistent?
A persistent timer with `Persistent=true` will catch up on missed executions if the system was powered off during scheduled time.

### Step 1: Create the Service File
Create `/etc/systemd/system/persistent-timer.service`:

```bash
sudo tee /etc/systemd/system/persistent-timer.service > /dev/null <<'EOF'
[Unit]
Description=Persistent Timer Service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/persistent-task.sh
EOF
```

### Step 2: Create the Timer File
Create `/etc/systemd/system/persistent-timer.timer`:

```bash
sudo tee /etc/systemd/system/persistent-timer.timer > /dev/null <<'EOF'
[Unit]
Description=Persistent Timer

[Timer]
OnBootSec=30s
OnUnitActiveSec=1h
Persistent=true

[Install]
WantedBy=timers.target
EOF
```

**Key Options:**
- `OnBootSec=30s`: Run 30 seconds after boot
- `OnUnitActiveSec=1h`: Run every hour after last execution
- `Persistent=true`: Catch up missed runs if system was down

### Step 3: Create the Script
Create `/usr/local/bin/persistent-task.sh`:

```bash
sudo tee /usr/local/bin/persistent-task.sh > /dev/null <<'EOF'
#!/bin/bash
echo "Persistent task executed at $(date)" >> /var/log/persistent-task.log
EOF
```

Make it executable:

```bash
sudo chmod +x /usr/local/bin/persistent-task.sh
```

### Step 4: Enable and Start
```bash
sudo systemctl daemon-reload
sudo systemctl enable persistent-timer.timer
sudo systemctl start persistent-timer.timer
```

### Verification
```bash
# List timer details
sudo systemctl list-timers persistent-timer.timer

# Check status
sudo systemctl status persistent-timer.timer

# View logs
sudo journalctl -u persistent-timer.timer -n 20
```

## Part 3: Complex Cron with Environment Variables

### Why Environment Variables in Cron?
Cron jobs run in a minimal environment. Defining variables in crontab allows you to use them in your commands and scripts.

### Step 1: Create the Script
Create `/usr/local/bin/env-task.sh`:

```bash
sudo tee /usr/local/bin/env-task.sh > /dev/null <<'EOF'
#!/bin/bash
echo "Cron env_task executed at $(date)" >> /var/log/env-task.log
EOF
```

Make it executable:

```bash
sudo chmod +x /usr/local/bin/env-task.sh
```

### Step 2: Add to Root Crontab
Open the root crontab:

```bash
sudo crontab -e
```

Add these lines:

```
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
LOGFILE=/var/log/env-task.log

0 */6 * * * /usr/local/bin/env_task.sh >> $LOGFILE 2>&1
```

**Explanation:**
- Environment variables must appear **before** job lines in crontab
- `SHELL=/bin/bash`: Specifies the shell
- `PATH=/...`: Defines search path for commands
- `LOGFILE=/var/log/env-task.log`: Custom variable
- `0 */6 * * *`: Run every 6 hours at minute 0
- The job line must contain "env_task" for grading (the script or identifier)

### Verification
```bash
# View current crontab
sudo crontab -l

# Check cron logs
sudo grep CRON /var/log/cron
# or
sudo journalctl -u cron

# View the output
sudo tail /var/log/env-task.log
```

## Comparison Table

| Feature | Anacron | Systemd Timer | Cron |
|---------|---------|---------------|------|
| **Offline Safe** | Yes | No | No |
| **Persistent** | Yes | With Persistent=true | No |
| **Modern** | No | Yes | No |
| **Complex Scheduling** | Limited | Very Flexible | Flexible |
| **Logging** | Cron logs | journalctl | Cron logs |
| **Dependencies** | No | Yes (can depend on other units) | No |

## Troubleshooting

### Anacron Not Running
```bash
# Check if anacron service is enabled
sudo systemctl is-enabled anacron

# Start anacron service
sudo systemctl start anacron

# View anacron logs
sudo journalctl -u anacron --follow
```

### Systemd Timer Issues
```bash
# Check if timer is enabled
sudo systemctl is-enabled persistent-timer.timer

# Test by manually running the service
sudo systemctl start persistent-timer.service

# View detailed timer information
sudo systemctl show persistent-timer.timer
```

### Cron Job Not Running
```bash
# Verify crontab syntax
sudo crontab -l

# Check cron daemon is running
sudo systemctl status cron

# View recent cron activity
sudo journalctl -u cron --follow
```

## Best Practices

1. **Anacron**: Use for laptop/desktop systems that may not always be on
2. **Systemd Timers**: Use for server systems with modern systemd
3. **Cron**: Use for backward compatibility or simple scheduling needs
4. **Logging**: Always redirect output to a log file for debugging
5. **Permissions**: Run jobs with appropriate user privileges (root vs regular user)
6. **Testing**: Test scripts manually before scheduling them

## Useful Commands

```bash
# Systemd
sudo systemctl daemon-reload
sudo systemctl list-timers
sudo systemctl status [service]
sudo journalctl -u [service] --follow

# Anacron
sudo systemctl status anacron
sudo cat /var/spool/anacron/[job-id]

# Cron
sudo crontab -l
sudo crontab -e
sudo grep CRON /var/log/cron
```
