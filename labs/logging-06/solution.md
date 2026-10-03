# logging-06: journald size limits, rate limiting and retention

## Hints

1. Like a unit, journald reads its main file and then every file
   ending in .conf in a directory named after it with the suffix .d.
   Settings in a later file replace those in an earlier one. See
   man journald.conf, section Configuration Directories and
   Precedence.
2. All settings belong in the Journal section. Sizes take the
   suffixes K, M and G, and time spans the units of
   man systemd.time, such as week. The command systemd-analyze has a
   subcommand cat-config that shows the combined configuration.
3. journald reads its configuration only when it starts. After the
   restart it may keep writing to /run/log/journal until it is asked
   to flush, which the command journalctl can do. journald then logs
   the size and maximum of the system journal in its own messages.
4. The command logger sends a message to the journal, and its man
   page names the option for the tag. rsyslog reads the journal and
   can lose track of it when the journal moves from /run to
   /var/log/journal. Restarting rsyslog makes it open the journal
   files again.

## Solution

1. [sudo] Create the drop-in file and check the combined
   configuration:

   ```bash
   sudo mkdir -p /etc/systemd/journald.conf.d
   cd /etc/systemd/journald.conf.d
   sudo tee 50-limits.conf >/dev/null <<'CONF'
   [Journal]
   Storage=persistent
   SystemMaxUse=100M
   SystemMaxFileSize=20M
   RateLimitIntervalSec=10s
   RateLimitBurst=500
   MaxRetentionSec=2week
   CONF
   systemd-analyze cat-config systemd/journald.conf
   ```

2. [sudo] Restart journald, move the journal from memory to
   /var/log/journal and check the result:

   ```bash
   sudo systemctl restart systemd-journald
   sudo journalctl --flush
   ls /var/log/journal/$(cat /etc/machine-id)
   sudo journalctl -u systemd-journald -n 5
   journalctl --disk-usage
   ```

3. [sudo] Restart rsyslog, so that its journal reader opens the new
   journal files in /var/log/journal:

   ```bash
   sudo systemctl restart rsyslog
   ```

4. [user] Log the message:

   ```bash
   logger -t labjournal "journald limits applied"
   ```

5. [sudo] Check that it is in the journal and in /var/log/messages:

   ```bash
   sudo journalctl -t labjournal -n 1
   sudo grep labjournal /var/log/messages
   ```

6. [sudo] Practice (not graded): vacuum the journal and test the rate
   limit:

   ```bash
   sudo journalctl --vacuum-size=50M
   journalctl --disk-usage
   for i in $(seq 600); do logger -t flood "message $i"; done
   sudo journalctl -t systemd-journald -n 5
   ```

## Verification

```bash
labctl grade logging-06
```

## Explanation

journald reads /etc/systemd/journald.conf and then the drop-ins in
/etc/systemd/journald.conf.d in name order, and for each setting the
last value wins. A drop-in keeps local settings apart from the file the
systemd package ships, so a package update never conflicts with them.
systemd-analyze cat-config shows the files in the order journald reads
them, and the grader uses it to find the effective values. The grader
accepts any spelling of the same value, such as 14d for 2week.

The defaults on Rocky Linux 8 and 9 are Storage=auto (persistent only
when /var/log/journal exists), SystemMaxUse at 10 percent of the file
system with a cap of 4G, SystemMaxFileSize at one eighth of that, a
rate limit of 10000 messages in 30 seconds per service and no
retention limit. The rate limit counts messages per service: a
service that logs more than 500 messages within 10 seconds loses the
rest of that interval, and journald logs how many it suppressed.

journald reads its settings only at startup. With Storage=persistent it
creates /var/log/journal itself. On Rocky Linux 9 a restarted journald
keeps writing to /run/log/journal until journalctl --flush asks it to
move to /var/log/journal; on Rocky Linux 8 it often moves on its own.
The flush works on both. When journald opens the system journal it
logs a line such as "System Journal (/var/log/journal/...) is 24.2M,
max 100.0M", which shows the limit in use.

rsyslog on Rocky Linux reads the journal through its imjournal module,
so every message logged with logger also lands in /var/log/messages.
The ForwardToSyslog setting is not needed for that, and on these
systems nothing listens on the socket it would write to. imjournal
opens the journal files when rsyslog starts. On Rocky Linux 9 it does
not notice that journald moved to /var/log/journal, which did not
exist when rsyslog started, and /var/log/messages stops receiving new
messages. A restart of rsyslog fixes that; it then also writes the
messages it missed, since it remembers its position in the journal.
Rocky Linux 8 follows the move on its own, and the restart does no
harm there.
