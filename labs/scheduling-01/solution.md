# scheduling-01: Cron jobs basics

## Solution

1. [sudo] Open the root crontab in an editor:

   ```bash
   sudo crontab -e
   ```

2. [sudo] Add this line, then save and exit the editor:

   ```
   0 2 * * * echo 'Daily task executed' >> /var/log/daily-task.log
   ```

3. [sudo] List the root crontab to confirm the entry:

   ```bash
   sudo crontab -l
   ```

## Verification

```bash
sudo crontab -l
labctl grade scheduling-01
```

## Explanation

The five time fields are minute, hour, day of month, month and day of
week. `0 2 * * *` means minute 0 of hour 2 on every day. Using
`sudo crontab -e` edits the crontab of root, which is where the grader
looks; plain `crontab -e` would edit the crontab of your own user.

`>>` appends to the log file. A single `>` would overwrite it on every
run, so only the last line would remain. The file is created by the
first run, so it does not exist after you add the entry.
