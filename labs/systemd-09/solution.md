# systemd-09: Runaway processes and sar data collection

## Hints

1. Sort the processes by CPU usage and then by resident memory to
   find the two hogs. The command top can sort by either column,
   and ps has a sort option. Note the process IDs.
2. The command systemctl status accepts a process ID instead of a
   unit name and shows the unit the process belongs to. A stopped
   service can still be started again by another unit: compare the
   ACTIVATES column of the list of timers with that service.
3. Stopping a unit ends it now, disabling it removes it from boot.
   The timer and the memory hog service need both. The service of
   the CPU hog has no Install section, so stopping it is enough once
   its timer is gone. See man systemctl, disable --now.
4. OnCalendar in a timer is a list. In a drop-in, an empty
   OnCalendar= line first clears the vendor schedule, then a second
   line sets the new one. Read man systemd.time, section Calendar
   Events, for the syntax of every 2 minutes.

## Solution

1. [user] Find the two hogs, by CPU and by resident memory:

   ```bash
   ps -eo pid,user,ni,%cpu,rss,comm --sort=-%cpu | head -5
   ps -eo pid,user,ni,%cpu,rss,comm --sort=-rss | head -5
   ```

   The CPU hog is report-cache, the memory hog is index-builder.

2. [user] Find the unit of each process:

   ```bash
   systemctl status "$(pgrep -x report-cache)"
   systemctl status "$(pgrep -x index-builder)"
   ```

   report-cache runs in report-cache.service, index-builder in
   index-builder.service.

3. [user] Find what starts report-cache.service again. On Rocky 9
   systemctl status shows a TriggeredBy line; on Rocky 8 the list of
   timers shows it:

   ```bash
   systemctl list-timers --all
   systemctl cat report-cache.timer index-builder.service
   ```

4. [sudo] Stop and disable the timer first, then stop the service,
   so the timer cannot start it again. Stop and disable the memory
   hog:

   ```bash
   sudo systemctl disable --now report-cache.timer
   sudo systemctl stop report-cache.service
   sudo systemctl disable --now index-builder.service
   ```

5. [user] Write the name of the timer to culprit.txt:

   ```bash
   echo report-cache.timer > ~/culprit.txt
   ```

6. [sudo] Install sysstat if it is missing:

   ```bash
   rpm -q sysstat || sudo dnf -y install sysstat
   ```

7. [sudo] Create the drop-in for the timer. The command opens an
   editor; enter the lines below, save and quit:

   ```bash
   sudo systemctl edit sysstat-collect.timer
   ```

   ```
   [Timer]
   OnCalendar=
   OnCalendar=*:00/2
   ```

   Without an editor, write the same file directly and reload:

   ```bash
   sudo mkdir -p /etc/systemd/system/sysstat-collect.timer.d
   sudo tee /etc/systemd/system/sysstat-collect.timer.d/override.conf \
       >/dev/null <<'CONF'
   [Timer]
   OnCalendar=
   OnCalendar=*:00/2
   CONF
   sudo systemctl daemon-reload
   ```

8. [sudo] Enable and start the timer, and take a first sample now so
   that the timer only has to add one more:

   ```bash
   sudo systemctl enable --now sysstat-collect.timer
   sudo systemctl start sysstat-collect.service
   ```

9. [user] Wait until the next even minute has passed, then check that
   sar shows at least one line of CPU statistics:

   ```bash
   systemctl list-timers sysstat-collect.timer
   sar
   ```

## Verification

```bash
top -b -n 1 | head -15
systemctl show -p TimersCalendar sysstat-collect.timer
rpm -V sysstat
labctl grade systemd-09
```

## Explanation

The CPU hog is a busy loop that systemd keeps at nice 19 and half a
CPU (CPUQuota=50%), so the machine stays usable, but it still tops the
CPU column. Killing it only helps for a minute: report-cache.timer
fires every minute and starts report-cache.service again whenever it is
not running. A timer activates the service of the same name unless its
Unit= setting names another one. That is why the timer is the culprit,
and why it must be disabled and stopped before the service.

index-builder holds a string of about 250 MiB. Restart=always makes
systemd start it again 3 seconds after any exit, also after SIGKILL.
Only systemctl stop ends it for good, because a stop requested through
systemd is never restarted. MemoryMax is a safety cap: the kernel kills
the process if it grows past 320M.

sysstat ships sysstat-collect.timer with the same name and the same
schedule on Rocky 8 (sysstat 11.7) and Rocky 9 (sysstat 12.5). It runs
sysstat-collect.service, which calls sa1 to append one sample to
/var/log/sa/saDD, where DD is the day of the month. The timer and
sysstat-summary.timer are WantedBy=sysstat.service, and sysstat.service
names them with Also=, so enabling sysstat.service enables both timers
too. sysstat.service itself only writes a restart record at boot. The
package presets the units as enabled on install but does not start
them, so the timer is inactive until it is started or the machine
reboots.

OnCalendar can be given several times, and every value adds an event.
Without the empty OnCalendar= line the drop-in would keep the vendor
event of every 10 minutes next to the new one. systemctl shows the
result in normalized form, *-*-* *:00/2:00, whatever spelling was
used. sar computes rates from the difference between two samples, so
one sample alone shows no statistics.
