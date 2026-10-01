# logging-02: Custom rsyslog rules and logrotate

## Hints

1. Two files are involved. rsyslog decides where messages go, so write
   the rules in /etc/rsyslog.d/myapp.conf. logrotate handles rotation
   through its own file in /etc/logrotate.d.
2. In man rsyslog.conf, read the sections on selectors (facility and
   priority) and on property-based filters. The first rule selects by
   facility, the second by the program name, which is the tag.
3. rsyslog creates new files with mode 600, so create both log files
   yourself and set the mode before testing. Restart the service so
   it reads the new rules.
4. In man logrotate, look for the directives for daily rotation, the
   number of kept logs, compression, missing and empty files, and
   create. The reopen step belongs in a postrotate script. Check the
   file with the debug option, which changes nothing.

## Solution

1. [sudo] Create the rsyslog rules:

   ```bash
   sudo tee /etc/rsyslog.d/myapp.conf >/dev/null <<'EOT'
   local0.*                            /var/log/myapp.log
   :programname, isequal, "myapp"      /var/log/myapp-program.log
   EOT
   ```

2. [sudo] Create the log files with mode 644:

   ```bash
   sudo touch /var/log/myapp.log /var/log/myapp-program.log
   sudo chmod 644 /var/log/myapp.log /var/log/myapp-program.log
   ```

3. [sudo] Restart rsyslog so that it loads the rules:

   ```bash
   sudo systemctl restart rsyslog
   ```

4. [sudo] Create the logrotate configuration and check its syntax:

   ```bash
   sudo tee /etc/logrotate.d/myapp >/dev/null <<'EOT'
   /var/log/myapp.log /var/log/myapp-program.log {
       daily
       rotate 7
       compress
       missingok
       notifempty
       create 644 root root
       postrotate
           systemctl kill -s HUP rsyslog >/dev/null 2>&1 || true
       endscript
   }
   EOT
   sudo logrotate -d /etc/logrotate.d/myapp
   ```

5. [user] Optional: send test messages and look for them:

   ```bash
   logger -p local0.info -t other "Facility message"
   logger -t myapp "Program message"
   sleep 2
   grep "Facility message" /var/log/myapp.log
   grep "Program message" /var/log/myapp-program.log
   ```

## Verification

```bash
labctl grade logging-02
```

## Explanation

The rule `local0.*` selects by facility, the property filter
`:programname, isequal, "myapp"` selects by the tag given to logger.
A message with both facility local0 and tag myapp matches both rules
and is written to both files. rsyslog has no reload action on Rocky
(its unit has no ExecReload), so the configuration is loaded by a
restart.

rsyslog creates new log files with mode 600 unless told otherwise,
which is why the files are created and set to 644 beforehand. The
postrotate script sends SIGHUP so that rsyslog closes the rotated
file and opens a new one. Without it rsyslog keeps writing to the
renamed file. The pid file of rsyslog is /run/rsyslogd.pid, not
syslogd.pid, so signalling through the unit is more reliable.
