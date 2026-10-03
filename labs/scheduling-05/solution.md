# scheduling-05: Troubleshoot cron jobs that never run

## Hints

Task 1: the backup job

1. The cron daemon writes to /var/log/cron why it skips a file or a
   job. Read the lines that name lab-backup.
2. The daemon ignores a file in /etc/cron.d that the group or others
   can write. Compare the mode of lab-backup with the other files in
   that directory.

Task 2: the cleanup job

1. Compare the job line in lab-cleanup with the lines in /etc/crontab
   and with the user name that /var/log/cron reports for it.
2. A line in /etc/cron.d has one field more than a line in a user
   crontab: the user name between the schedule and the command. See
   man 5 crontab.

Task 3: the job of reports

1. Once the job starts, /var/log/cron shows the command that cron
   actually ran and its output. Compare that command with the line in
   the crontab of reports.
2. In a crontab, a percent sign in the command ends the command and
   starts its standard input. man 5 crontab says how to write a
   literal percent sign.
3. A command that works in a login shell can still be missing under
   cron, which starts jobs with a short PATH. Set PATH in the crontab
   or call the helper by its full path.

## Solution

1. [sudo] Read what the cron daemon logs about the jobs:

   ```bash
   sudo grep -e lab- -e reports /var/log/cron | tail -n 20
   ```

   /etc/cron.d/lab-backup is skipped with BAD FILE MODE. For
   lab-cleanup the daemon looks up a user named
   /usr/local/sbin/lab-report (getpwnam() failed). The job of reports
   runs a command that ends at $(date + and fails with a shell syntax
   error.

2. [sudo] Remove the write permission of group and others from
   lab-backup:

   ```bash
   ls -l /etc/cron.d
   sudo chmod 0644 /etc/cron.d/lab-backup
   ```

3. [sudo] Add the user field root to the job line in lab-cleanup:

   ```bash
   sudo sed -i 's| /usr/local/sbin/lab-report| root&|' \
       /etc/cron.d/lab-cleanup
   cat /etc/cron.d/lab-cleanup
   ```

4. [sudo] Look at the crontab of reports. The percent sign is not
   escaped, and the bare name lab-report is not in the PATH of cron
   jobs (/usr/bin:/bin):

   ```bash
   sudo crontab -u reports -l
   ```

5. [sudo] Replace the crontab of reports with one that sets PATH and
   escapes the percent sign:

   ```bash
   sudo crontab -u reports - <<'EOF2'
   # Daily report for the reports team, every minute
   PATH=/usr/local/sbin:/usr/bin:/bin
   * * * * * lab-report $(date +\%F) >>/var/log/cronlab/daily.log 2>&1
   EOF2
   ```

6. [sudo] Wait for the next full minute and read the logs:

   ```bash
   sleep 65
   tail -n 1 /var/log/cronlab/backup.log /var/log/cronlab/cleanup.log
   tail -n 1 /var/log/cronlab/daily.log
   ```

## Verification

```bash
systemctl is-active crond
ls -l /etc/cron.d/lab-backup /etc/cron.d/lab-cleanup
labctl grade scheduling-05
```

## Explanation

crond reads /etc/cron.d at every minute and refuses a file that is not
owned by root or that the group or others can write, because anyone
who can write it could run commands as root. It logs BAD FILE MODE once
and then ignores the file. A change of mode is enough; crond notices it
without a restart.

Lines in /etc/crontab and /etc/cron.d have a sixth field, the user that
runs the command. Without it, crond takes the first word of the command
as the user name, cannot find that user and skips the line every
minute.

In a crontab, an unescaped percent sign ends the command, and the rest
of the line becomes the standard input of the command. The shell then
sees an unfinished $(date + and fails, and the redirection to the log
never happens, so the error only shows in /var/log/cron. Once the
percent sign is escaped as \%, the redirection works and the log shows
the next problem: cron starts jobs with PATH=/usr/bin:/bin, so
lab-report is not found, although it runs fine in a login shell. A
PATH line in the crontab or the full path /usr/local/sbin/lab-report
fixes it; the grader accepts both.

The helper writes the name of the user that runs it, so the grader can
tell that the job of reports really runs as reports. It accepts a line
from the last 3 minutes and waits up to 75 seconds for the next run.
