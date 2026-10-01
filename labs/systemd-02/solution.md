# systemd-02: Custom systemd service

## Solution

1. [sudo] Create the executable script:

   ```bash
   sudo tee /opt/custom-app.sh >/dev/null <<'SCRIPT'
   #!/bin/bash
   while true; do
       echo "Custom app running at $(date)" >> /var/log/custom-app.log
       sleep 5
   done
   SCRIPT
   sudo chmod +x /opt/custom-app.sh
   ```

2. [sudo] Create the service unit:

   ```bash
   cd /etc/systemd/system
   sudo tee custom-app.service >/dev/null <<'SERVICE'
   [Unit]
   Description=Custom Application Service
   After=network.target

   [Service]
   Type=simple
   ExecStart=/opt/custom-app.sh
   Restart=on-failure
   RestartSec=5

   [Install]
   WantedBy=multi-user.target
   SERVICE
   ```

3. [sudo] Reload systemd, enable the service and start it:

   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable custom-app.service
   sudo systemctl start custom-app.service
   ```

## Verification

```bash
systemctl status custom-app.service
systemctl is-enabled custom-app.service
tail /var/log/custom-app.log
labctl grade systemd-02
```

## Explanation

systemd reads unit files from /etc/systemd/system. After creating or
changing one, daemon-reload makes systemd reread it. The [Install]
section with WantedBy=multi-user.target is what enable acts on: it
creates a symlink in multi-user.target.wants, so the service starts at
boot. Type=simple means systemd treats the started process itself as
the service, which is why the script loops in the foreground instead of
forking.

The script must be executable, otherwise the unit fails at start with
status 203/EXEC.
