# scheduling-04: One-time jobs with at and a default umask

## Hints

1. at reads the commands of a job from standard input and takes the
   time and date as arguments. Read man at, including the time formats
   it accepts, and man atq.
2. When /etc/at.allow exists, only the users listed in it may use at,
   and /etc/at.deny is not read. See man at.allow.
3. A login shell of bash reads ~/.bash_profile, which in turn reads
   ~/.bashrc. The umask builtin sets the mode mask for new files.
4. The system files /etc/profile and /etc/bashrc set a umask too. Your
   own line has to come after them, at the end of ~/.bashrc.

## Solution

1. [sudo] Enable and start atd:

   ```bash
   sudo systemctl enable --now atd
   ```

2. [user] Queue the job as yourself, not with sudo. at prints the job
   number and the time:

   ```bash
   echo "df -h > $HOME/disk-report.txt" | at 23:30 Dec 31
   atq
   at -c $(atq | awk '{ print $1 }' | tail -n 1) | tail -n 3
   ```

   The double quotes let your shell put the full path of your home
   directory into the job.

3. [sudo] Write /etc/at.allow with the three users:

   ```bash
   printf '%s\n' root $USER reporter | sudo tee /etc/at.allow
   sudo runuser -u intern -- at -l
   ```

   The last command prints that intern has no permission to use at.

4. [user] Add the umask to the end of ~/.bashrc and check it in a new
   login shell:

   ```bash
   echo 'umask 027' >> ~/.bashrc
   bash -l -c umask
   ```

## Verification

```bash
atq
cat /etc/at.allow
bash -l -c 'umask; touch /tmp/umask-test; stat -c %a /tmp/umask-test'
rm -f /tmp/umask-test
labctl grade scheduling-04
```

## Explanation

at runs a job once at the given time, with the environment and working
directory it had when it was queued. `at 23:30 Dec 31` names a fixed
date, so the job stays in the queue during the lab. A job queued with
sudo would belong to root, and the grader looks for a job of your own
user. `at -c` shows the saved environment and, at the end, the
commands of the job.

/etc/at.allow is a list of allowed users. Once it exists, every user
who is not in it is denied, whatever /etc/at.deny says. Without
at.allow, at.deny lists the denied users, and an empty at.deny allows
everyone.

The umask removes permission bits from the default modes 666 for files
and 777 for directories. 027 removes write for the group and all bits
for others, so files get 640 and directories 750. /etc/bashrc sets a
umask of 002 or 022, so the line has to come after ~/.bashrc reads
/etc/bashrc, which is the case at the end of the file. The umask also
applies to shells you open later, not to the shell that is already
running.
