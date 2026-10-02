# logging-04: Persistent audit rules and auditd log settings

## Hints

1. Rules that survive a reboot live in files in /etc/audit/rules.d.
   The helper augenrules merges them into /etc/audit/audit.rules and
   can load the result into the kernel. Read man augenrules.
2. man audit.rules describes the two rule kinds: a file watch with
   permissions and a key, and a system call rule with an action,
   a list, an architecture, system calls, fields and a key.
3. The field auid is the login UID. A process that never logged in
   has the login UID unset, which audit.rules calls unset or -1 and
   which is a number above 1000.
4. auditd rereads auditd.conf on the signal SIGHUP. The command
   service auditd reload sends it; systemctl cannot restart auditd.

## Solution

1. [sudo] Write the persistent rules file. One watch for writes and
   attribute changes, and one rule per architecture for deletions and
   renames by users with a set login UID of 1000 or higher:

   ```bash
   S='-S unlink,unlinkat,rename,renameat'
   F='-F auid>=1000 -F auid!=unset -k lab_delete'
   {
     echo '-w /etc/lab-app.conf -p wa -k lab_config'
     echo "-a always,exit -F arch=b64 $S $F"
     echo "-a always,exit -F arch=b32 $S $F"
   } | sudo tee /etc/audit/rules.d/lab-audit.rules
   sudo chmod 600 /etc/audit/rules.d/lab-audit.rules
   ```

   The two system call rules are each one line in the file, for
   example:

   ```
   -a always,exit -F arch=b64 -S unlink,unlinkat,rename,renameat \
     -F auid>=1000 -F auid!=unset -k lab_delete
   ```

   The backslash only marks the wrap on this page; a rules file has
   no continuation lines.

2. [sudo] Merge the rules files into audit.rules, load them and list
   the loaded rules:

   ```bash
   sudo augenrules --load
   sudo augenrules --check
   sudo auditctl -l
   ```

3. [sudo] Set the two values in auditd.conf and make auditd read the
   file again:

   ```bash
   sudo sed -i -e 's/^max_log_file *=.*/max_log_file = 25/' \
     -e 's/^max_log_file_action *=.*/max_log_file_action = keep_logs/' \
     /etc/audit/auditd.conf
   sudo grep -E '^max_log_file' /etc/audit/auditd.conf
   sudo service auditd reload
   ```

4. [user] Test the rules: change the watched file, delete a file as
   yourself and search the log by key:

   ```bash
   sudo chmod 644 /etc/lab-app.conf
   touch /tmp/audit-test && rm /tmp/audit-test
   sudo ausearch -i -k lab_config -ts recent
   sudo ausearch -i -k lab_delete -ts recent
   ```

## Verification

```bash
sudo auditctl -l
labctl grade logging-04
```

## Explanation

auditctl changes only the rules in the kernel, and they are gone after
a reboot. At boot auditd runs augenrules, which joins every file in
/etc/audit/rules.d in name order into /etc/audit/audit.rules and loads
it. augenrules --load does the same at once, and augenrules --check
says whether audit.rules is still up to date with rules.d.

The watch -w with -p wa records writes and attribute changes such as
chmod, chown and touch. The system call rule matches on the login UID
(auid), which the kernel sets at login and keeps through su and sudo.
A deletion with sudo rm is therefore still recorded under your own
login UID. Services started at boot have no login UID (unset, shown
as -1), which is why the rule needs auid!=unset next to auid>=1000.
Without the arch field auditctl uses the architecture of auditctl
itself, so a separate b32 rule covers 32-bit programs. mv may use
renameat2, which can be added to the list as well.

auditd.conf is read at start and on SIGHUP. The auditd unit refuses
a manual stop, so systemctl restart auditd fails; service auditd
reload (or auditctl --signal reload) sends the signal and also reloads
the rules with augenrules. The grader checks for the DAEMON_CONFIG
record that auditd writes when it reads the file again. keep_logs
rotates like rotate but never deletes old logs, so num_logs no longer
limits them.
