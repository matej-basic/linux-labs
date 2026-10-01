# scheduling-01: Cron jobs basics

## Hints

1. A crontab entry has five time fields before the command. Check
   their order and meaning in man 5 crontab.
2. The entry must go into the crontab of root, so the editor has to be
   started with root rights. See the -e and -l options in man 1
   crontab.
3. The log line is added with the shell append redirection, not the
   overwrite one. The log file does not have to exist yet, the first
   run creates it.

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
