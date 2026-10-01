# scheduling-02: Systemd timers

## Hints

1. A timer unit does not run anything itself. It activates a service
   unit with the same base name, so you need a script, a service and a
   timer.
2. The service runs once and exits, which is a Type value described in
   man systemd.service. The timer keys OnBootSec and OnUnitActiveSec
   are in man systemd.timer.
3. Starting at boot comes from an [Install] section in the timer unit
   with WantedBy set to timers.target.
4. After writing the unit files, systemd has to reread them. Then
   the enable subcommand of systemctl with the --now option installs
   and starts the timer in one step.

## Solution

1. [sudo] Create the script and make it executable:

   ```bash
   sudo tee /usr/local/bin/lab-task.sh > /dev/null <<'EOF'
   #!/bin/bash
   echo "Lab task executed at $(date)" >> /var/log/lab-task.log
   EOF
   sudo chmod +x /usr/local/bin/lab-task.sh
   ```

2. [sudo] Create the service unit:

   ```bash
   sudo tee /etc/systemd/system/lab-task.service > /dev/null <<'EOF'
   [Unit]
   Description=Lab task service

   [Service]
   Type=oneshot
   ExecStart=/usr/local/bin/lab-task.sh
   EOF
   ```

3. [sudo] Create the timer unit:

   ```bash
   sudo tee /etc/systemd/system/lab-task.timer > /dev/null <<'EOF'
   [Unit]
   Description=Lab task timer

   [Timer]
   OnBootSec=1min
   OnUnitActiveSec=10min

   [Install]
   WantedBy=timers.target
   EOF
   ```

4. [sudo] Load the units, enable the timer and start it:

   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable --now lab-task.timer
   ```

## Verification

```bash
sudo systemctl list-timers lab-task.timer
sudo systemctl start lab-task.service
sudo tail /var/log/lab-task.log
labctl grade scheduling-02
```

## Explanation

The service has Type=oneshot because the script runs once and exits.
The timer fires the service of the same name. OnBootSec=1min gives
the first run one minute after boot. OnUnitActiveSec=10min counts
from the last activation of the service, so the runs repeat every 10
minutes. A timer with only OnBootSec would run once per boot.

The [Install] section with WantedBy=timers.target is what makes
enable create the symlink in timers.target.wants, so the timer comes
back after a reboot. Starting the timer by itself would not survive
one. After editing unit files, daemon-reload makes systemd read
them.

The grader reads the unit properties from systemd, so any equivalent
spelling of the times (60s for 1min) is accepted. It then starts the
service once and expects a new, timestamped line in the log.
