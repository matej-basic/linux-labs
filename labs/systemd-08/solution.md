# systemd-08: Drop-in overrides, restart policy and resource limits

## Hints

1. A unit can be changed without touching its file: systemd also reads
   files from a directory named after the unit with the suffix .d.
   Read man systemd.unit, the description of drop-in directories.
2. The command systemctl has a subcommand that opens an editor on a
   new drop-in file and reloads systemd when you save. It writes
   override.conf in the right directory. Do not use its option that
   copies the whole unit.
3. Restart and RestartSec are in man systemd.service, Environment in
   man systemd.exec, MemoryMax and CPUQuota in
   man systemd.resource-control. All of them go in the Service
   section of the drop-in.
4. A new environment only reaches a process that starts after the
   change, so restart the service once the drop-in is in place.

## Solution

1. [sudo] Create the drop-in file. The command opens an editor; enter
   the lines below, save and quit. systemd reloads its configuration
   when the editor exits:

   ```bash
   sudo systemctl edit labapp.service
   ```

   ```
   [Service]
   Restart=on-failure
   RestartSec=5
   Environment=LAB_MODE=production
   MemoryMax=128M
   CPUQuota=50%
   ```

   Without an editor, write the same file directly and reload:

   ```bash
   sudo mkdir -p /etc/systemd/system/labapp.service.d
   sudo tee /etc/systemd/system/labapp.service.d/override.conf \
       >/dev/null <<'CONF'
   [Service]
   Restart=on-failure
   RestartSec=5
   Environment=LAB_MODE=production
   MemoryMax=128M
   CPUQuota=50%
   CONF
   sudo systemctl daemon-reload
   ```

2. [sudo] Enable the service and restart it, so that the running
   process gets the new environment:

   ```bash
   sudo systemctl enable labapp.service
   sudo systemctl restart labapp.service
   ```

## Verification

```bash
systemctl cat labapp.service
systemctl show labapp.service -p Restart -p RestartUSec \
    -p Environment -p MemoryMax -p CPUQuotaPerSecUSec
sudo systemctl kill -s KILL --kill-who=main labapp.service
sleep 6
systemctl status labapp.service
labctl grade systemd-08
```

## Explanation

Files under /usr/lib/systemd/system belong to packages, and an update
overwrites them. A full copy in /etc/systemd/system takes precedence
over the vendor file completely, so later fixes from the package never
take effect. A drop-in file in labapp.service.d changes only the keys
it names and keeps the rest of the vendor unit. systemctl cat shows the
vendor file followed by every drop-in, in the order systemd applies
them.

Environment is a list: the drop-in adds LAB_MODE=production after the
LAB_MODE=development of the vendor unit, and the later assignment wins.
A running process keeps the environment it started with, which is why
the grader checks /proc of the main process and the service needs a
restart.

MemoryMax and CPUQuota are applied to the control group of the
service. systemd 239 on Rocky 8 uses cgroup v1 and translates MemoryMax
to the v1 memory limit; Rocky 9 uses cgroup v2. The settings and the
values systemctl show reports are the same on both, and CPUQuota=50%
appears as CPUQuotaPerSecUSec=500ms. MemoryLimit is the older v1-only
name and does not set MemoryMax.

Restart=on-failure restarts the service after an unclean exit, which
includes being killed by SIGKILL, but not after a clean stop with
systemctl stop. RestartSec=5 is the pause before the new start.
