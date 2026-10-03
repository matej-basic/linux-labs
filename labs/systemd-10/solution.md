# systemd-10: Custom services that fail to start

## Hints

1. Look at the status and the journal of each service. The result and
   the exit status name the kind of failure: 203/EXEC means that
   systemd could not run the program at all, a timeout means that
   systemd waited for something that never happened.
2. systemd runs a program only when it has an execute bit and an
   SELinux type that the service may execute. A file that was created
   in /root and moved keeps the type of /root. The option -Z of ls
   shows the type, and restorecon sets the default one.
3. A file named in EnvironmentFile= must exist unless the name starts
   with a dash. Look in /etc/sysconfig for the settings that were
   prepared for inventoryd, and in the program for the variables it
   needs.
4. With Type=forking, systemd waits until the program forks and the
   first process exits. A program that stays in the foreground needs
   the type simple or exec. A unit without an [Install] section cannot
   be enabled; see man systemd.unit, section [Install] Section Options.

## Solution

1. [user] Find out how each service fails:

   ```bash
   systemctl status reportd inventoryd metricsd
   journalctl -u reportd -u inventoryd -u metricsd --no-pager
   ```

   reportd fails with status 203/EXEC, inventoryd cannot load its
   environment file, and metricsd times out after 20 seconds.

2. [sudo] reportd: the program has no execute bit and the type
   admin_home_t. Make it executable and restore its default type:

   ```bash
   ls -lZ /usr/local/bin/reportd
   sudo chmod 755 /usr/local/bin/reportd
   sudo restorecon -v /usr/local/bin/reportd
   ```

3. [sudo] inventoryd: the prepared settings are in
   /etc/sysconfig/inventoryd.example. Copy them to the file the unit
   reads:

   ```bash
   cat /etc/sysconfig/inventoryd.example
   sudo cp /etc/sysconfig/inventoryd.example /etc/sysconfig/inventoryd
   ```

4. [sudo] metricsd: change the type to simple and add an [Install]
   section. The command opens the full unit file in an editor:

   ```bash
   sudo systemctl edit --full metricsd.service
   ```

   Change Type=forking to Type=simple and add these lines at the end:

   ```
   [Install]
   WantedBy=multi-user.target
   ```

   Without an editor, make the same changes directly and reload:

   ```bash
   sudo sed -i 's/^Type=forking$/Type=simple/' \
       /etc/systemd/system/metricsd.service
   printf '\n[Install]\nWantedBy=multi-user.target\n' |
       sudo tee -a /etc/systemd/system/metricsd.service >/dev/null
   sudo systemctl daemon-reload
   ```

5. [sudo] Enable all three services and start them again. restart
   also replaces a start of metricsd that may still be waiting for
   the old type:

   ```bash
   sudo systemctl enable reportd inventoryd metricsd
   sudo systemctl restart reportd inventoryd metricsd
   ```

6. [user] Check the result:

   ```bash
   systemctl is-active reportd inventoryd metricsd
   ps -eo user,pid,args | grep /usr/local/bin/
   systemd-analyze verify /etc/systemd/system/reportd.service \
       /etc/systemd/system/inventoryd.service \
       /etc/systemd/system/metricsd.service
   ```

## Verification

```bash
systemctl status reportd inventoryd metricsd
labctl grade systemd-10
```

## Explanation

Status 203/EXEC means that systemd forked the service process but the
exec of the program failed. reportd has two causes for it, and each
one alone is enough. The file has mode 0644, so nobody may execute it.
It was also written in /root and moved to /usr/local/bin: mv keeps the
SELinux context, so the program has the type admin_home_t, and SELinux
does not let a service start a program of that type. restorecon sets
the type from the policy, bin_t for /usr/local/bin. Setting SELinux
to permissive would hide the second cause and is not a fix. The check
with systemd-analyze verify also reports a command that is not
executable, so it fails until the mode is fixed.

EnvironmentFile=/etc/sysconfig/inventoryd without a leading dash makes
the file mandatory: systemd does not even start the program when the
file is missing. With a dash the program would start and exit 1,
because it needs INVENTORY_DIR and SCAN_INTERVAL. The settings were
prepared in inventoryd.example and never copied into place.

Type=forking tells systemd that the start is complete when the first
process exits after starting a daemon in the background. metricsd
stays in the foreground, so systemd waits until TimeoutStartSec runs
out and kills it. Type=simple (or exec) treats the first process as
the main process. The unit had no [Install] section either, so
systemctl enable had nothing to do; WantedBy=multi-user.target makes
enable create the link in multi-user.target.wants.

The User= lines stay as they are. Running a service as root to get
around a permission problem hides the real fault and gives the
program more rights than it needs.
