# logging-03: Persistent journal and a failing service

## Solution

1. [sudo] Create the persistent journal directory and make journald use
   it:

   ```bash
   sudo mkdir -p /var/log/journal
   sudo chmod 755 /var/log/journal
   sudo systemctl restart systemd-journald
   sudo journalctl --flush
   journalctl --disk-usage
   ```

2. [sudo] Create the unit file:

   ```bash
   sudo tee /etc/systemd/system/labtest-fail.service >/dev/null <<'UNIT'
   [Unit]
   Description=Lab Test Fail Service

   [Service]
   Type=simple
   ExecStart=/bin/false

   [Install]
   WantedBy=multi-user.target
   UNIT
   ```

3. [sudo] Reload systemd and start the service. The start itself
   succeeds and the service then fails, so ignore the exit status:

   ```bash
   sudo systemctl daemon-reload
   sudo systemctl start labtest-fail.service || true
   systemctl is-failed labtest-fail.service
   ```

4. [sudo] Practice the analysis commands:

   ```bash
   sudo journalctl --list-boots
   sudo journalctl -b -n 20
   sudo journalctl -u labtest-fail.service -p err
   systemd-analyze time
   systemd-analyze blame
   systemd-analyze critical-chain
   sudo journalctl -b -k -n 20
   dmesg | tail -n 20
   ```

## Verification

```bash
labctl grade logging-03
```

## Explanation

Without /var/log/journal, journald with the default Storage=auto keeps
its files in /run/log/journal, which vanishes at reboot. Once the
directory exists and journald is restarted (or told to flush), it
writes to /var/log/journal/<machine-id>/, and --list-boots shows
earlier boots after the next reboot. journald may add the setgid bit to
the directory and set its group to systemd-journal; the grader accepts
that.

A Type=simple service counts as started as soon as the process is
forked, so systemctl start succeeds and /bin/false then exits with
status 1, leaving the unit in the failed state. /bin/false prints
nothing, so the journal holds only the systemd messages about the
start and the exit code. The grader does not read the journal itself,
because the normal user may lack permission to read it.
