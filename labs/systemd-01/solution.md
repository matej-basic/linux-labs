# systemd-01: Basic service management with systemd

## Solution

1. [sudo] Enable the service so it starts at boot:

   ```bash
   sudo systemctl enable test-service.service
   ```

2. [sudo] Start the service now:

   ```bash
   sudo systemctl start test-service.service
   ```

## Verification

```bash
systemctl is-enabled test-service.service
systemctl is-active test-service.service
systemctl status test-service.service
labctl grade systemd-01
```

## Explanation

Enabling and starting are independent. `enable` creates a symlink in
`/etc/systemd/system/multi-user.target.wants/` from the `WantedBy=`
line in the unit's `[Install]` section, so the service starts at the
next boot, but it does not start the service now. `start` runs it now
but does not make it persistent. The grader checks both, so doing only
one of the two leaves one criterion failing.

`enable --now` does both in one command.
