# systemd-03: Systemd timers and scheduled services

## Hints

1. Two of the three units are plain oneshot services. The third is a
   timer that triggers one of them. Build the script first, then the
   services, then the timer.
2. The timer options are in man systemd.timer. Compare the monotonic
   timers that count from boot with those that count from the last
   activation of the service.
3. The timer needs a Timer section with OnBootSec and OnUnitActiveSec,
   and an Install section with WantedBy=timers.target. The timer finds
   its service by the matching base name.
4. After daemon-reload, enable the timer, not the service. The timer
   may not fire for a while, so the log file may stay empty until you
   run the script some other way.

## Solution

1. [sudo] Create the worker script and make it executable:

   ```bash
   sudo tee /opt/lab-worker.sh >/dev/null <<'SCRIPT'
   #!/bin/bash
   mkdir -p /var/lib/lab-worker
   echo "Worker run at $(date)" >> /var/lib/lab-worker/execution.log
   SCRIPT
   sudo chmod 755 /opt/lab-worker.sh
   ```

2. [sudo] Create lab-worker.service:

   ```bash
   sudo tee /etc/systemd/system/lab-worker.service >/dev/null <<'UNIT'
   [Unit]
   Description=Lab worker

   [Service]
   Type=oneshot
   ExecStart=/opt/lab-worker.sh
   UNIT
   ```

3. [sudo] Create lab-timer.service, the unit the timer starts:

   ```bash
   sudo tee /etc/systemd/system/lab-timer.service >/dev/null <<'UNIT'
   [Unit]
   Description=Lab timer service

   [Service]
   Type=oneshot
   ExecStart=/opt/lab-worker.sh
   UNIT
   ```

4. [sudo] Create the timer:

   ```bash
   sudo tee /etc/systemd/system/lab-timer.timer >/dev/null <<'UNIT'
   [Unit]
   Description=Lab timer

   [Timer]
   OnBootSec=1min
   OnUnitActiveSec=5min

   [Install]
   WantedBy=timers.target
   UNIT
   ```

5. [sudo] Load the units, enable the timer and start it:

   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable --now lab-timer.timer
   ```

6. [sudo] Run the worker once so that the log has an entry:

   ```bash
   sudo systemctl start lab-timer.service
   ```

## Verification

```bash
systemctl list-timers lab-timer.timer
systemctl status lab-timer.timer
cat /var/lib/lab-worker/execution.log
labctl grade systemd-03
```

## Explanation

The timer starts the service with the same base name, lab-timer.service,
unless Unit= says otherwise. lab-worker.service is not used by the
timer; the task asks for it as a second unit that runs the same script.

OnBootSec is measured from boot and OnUnitActiveSec from the last time
the triggered service became active, so the run repeats every five
minutes. Both are monotonic timers. When the system has been up for
more than a minute, the first run may not happen right away, so step 6
starts the service by hand.

A unit file is only read after daemon-reload. enable creates the symlink
in timers.target.wants from the WantedBy= line, which is what makes the
timer start at boot, and --now also starts it. A oneshot service stays
inactive after it exits, so the grader checks the timer for the active
state, not the service.
