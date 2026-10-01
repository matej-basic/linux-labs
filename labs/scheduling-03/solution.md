# scheduling-03: Anacron, persistent timers and cron variables

## Solution

1. [sudo] Create the anacron script and make it executable:

   ```bash
   sudo tee /usr/local/bin/anacron-task.sh > /dev/null <<'EOF'
   #!/bin/bash
   echo "Anacron task ran at $(date)" >> /var/log/anacron-task.log
   EOF
   sudo chmod +x /usr/local/bin/anacron-task.sh
   ```

2. [sudo] Append the job to /etc/anacrontab (period, delay, job
   identifier, command) and check the syntax:

   ```bash
   echo '1 5 anacron_lab /usr/local/bin/anacron-task.sh' |
     sudo tee -a /etc/anacrontab > /dev/null
   sudo anacron -T
   ```

3. [sudo] Create the timer script and make it executable:

   ```bash
   sudo tee /usr/local/bin/persistent-task.sh > /dev/null <<'EOF'
   #!/bin/bash
   echo "Persistent task ran at $(date)" >> /var/log/persistent-task.log
   EOF
   sudo chmod +x /usr/local/bin/persistent-task.sh
   ```

4. [sudo] Create the service unit:

   ```bash
   cd /etc/systemd/system
   sudo tee persistent-timer.service > /dev/null <<'EOF'
   [Unit]
   Description=Persistent timer service

   [Service]
   Type=oneshot
   ExecStart=/usr/local/bin/persistent-task.sh
   EOF
   ```

5. [sudo] Create the timer unit:

   ```bash
   cd /etc/systemd/system
   sudo tee persistent-timer.timer > /dev/null <<'EOF'
   [Unit]
   Description=Persistent timer

   [Timer]
   OnBootSec=30s
   OnUnitActiveSec=1h
   Persistent=true

   [Install]
   WantedBy=timers.target
   EOF
   ```

6. [sudo] Load the units, then enable and start the timer:

   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable --now persistent-timer.timer
   ```

7. [sudo] Create the cron script, which writes to the file named by
   LOGFILE:

   ```bash
   sudo tee /usr/local/bin/env-task.sh > /dev/null <<'EOF'
   #!/bin/bash
   echo "env_task ran at $(date)" >> "${LOGFILE:-/var/log/env-task.log}"
   EOF
   sudo chmod +x /usr/local/bin/env-task.sh
   ```

8. [sudo] Add the variables and the job to root's crontab. The
   variables come first. The commands keep the existing crontab, if
   there is one:

   ```bash
   { sudo crontab -l 2>/dev/null || true
     cat <<'EOF'
   SHELL=/bin/bash
   PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
   LOGFILE=/var/log/env-task.log
   0 */6 * * * /usr/local/bin/env-task.sh
   EOF
   } | sudo crontab -
   ```

## Verification

```bash
sudo systemctl list-timers persistent-timer.timer
sudo crontab -l
labctl grade scheduling-03
```

## Explanation

Rocky Linux has no anacron service. The cronie-anacron package runs
anacron from /etc/cron.hourly/0anacron, and a job in /etc/anacrontab
runs once per period after the delay, also when the machine was off at
the usual time. The spool file /var/spool/anacron/anacron_lab holds the
date of its last run.

In the timer, OnBootSec starts the first run 30 seconds after boot and
OnUnitActiveSec repeats it one hour after each activation of the
service. Persistent=true stores the last trigger time on disk, so a
calendar-based run missed during downtime is made up at the next start.
Without WantedBy=timers.target the timer would not start at boot, and a
new unit file is not seen until systemctl daemon-reload.

Cron starts jobs with a minimal environment. Variable assignments in the
crontab apply to the job lines below them, so they must come before the
job. A job line that is above SHELL, PATH or LOGFILE does not see them.
`0 */6 * * *` means minute 0 of hours 0, 6, 12 and 18.
