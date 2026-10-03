# systemd-06: Process priorities and signals

## Hints

1. Find the process ID of each worker first. Its process name is the
   name of the program, so you can search for it by name.
2. The command renice changes the nice value of a running process by
   its process ID. Only root may lower a nice value, or change the
   nice value of a process that belongs to another user.
3. The command kill sends SIGTERM unless you name another signal.
   Read man 7 signal to see why SIGKILL cannot be ignored.
4. The command nice starts a program with a nice value. Combine it
   with nohup or setsid, redirect the output and run it in the
   background, so the program does not end when the session does.

## Solution

1. [user] Find the workers, their process IDs and their nice values:

   ```bash
   ps -o pid,user,ni,comm -C lab-report,lab-ingest,lab-stale,lab-hung
   ```

2. [sudo] Set the nice value of lab-report to 15:

   ```bash
   sudo renice -n 15 -p "$(pgrep -x lab-report)"
   ```

3. [sudo] Set the nice value of lab-ingest to -5:

   ```bash
   sudo renice -n -5 -p "$(pgrep -x lab-ingest)"
   ```

4. [sudo] End lab-stale with SIGTERM:

   ```bash
   sudo kill -TERM "$(pgrep -x lab-stale)"
   ```

5. [sudo] Check that lab-hung ignores SIGTERM, then end it with
   SIGKILL:

   ```bash
   sudo kill -TERM "$(pgrep -x lab-hung)"
   sleep 1
   pgrep -x lab-hung
   sudo kill -KILL "$(pgrep -x lab-hung)"
   ```

6. [user] Start lab-batch as your own user at nice 10, detached from
   the session, then log out:

   ```bash
   nohup nice -n 10 /usr/local/bin/lab-batch >/dev/null 2>&1 &
   exit
   ```

## Verification

```bash
ps -o pid,user,ni,comm -C lab-report,lab-ingest,lab-batch
pgrep -x lab-stale; pgrep -x lab-hung
labctl grade systemd-06
```

## Explanation

The nice value runs from -20 (highest priority) to 19 (lowest). Any
user may raise the nice value of their own processes, but only root
may lower it below its current value or change processes of other
users. The workers belong to labjobs, so steps 2 to 5 need sudo, and
-5 needs root anyway. renice changes the running process; restarting
a worker would give it a new process ID, which the grader rejects.

SIGTERM asks a process to end and can be caught or ignored, which is
what lab-hung does. SIGKILL is handled by the kernel and cannot be
caught or ignored, so it always ends the process, but the process gets
no chance to clean up. Use it only after SIGTERM failed.

nohup makes the program ignore SIGHUP, which the shell sends to its
jobs when the terminal goes away. setsid, or disown in bash, works as
well. With systemd-run --user the job runs in your user manager, which
stops when you log out unless lingering is enabled for your user
(loginctl enable-linger). On Rocky 8 the user manager does not apply
the Nice= property to the unit, so run nice -n 10 as the command of
the unit there. Started with sudo, lab-batch would run as root and
fail the grader.
