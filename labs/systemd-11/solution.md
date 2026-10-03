# systemd-11: Persistent kernel parameters and tmpfiles.d rules

## Hints

Task 2: the conflict

1. At boot, systemd-sysctl reads the files of several directories and
   applies them in the order of their file names. When two files set
   the same parameter, the file applied last wins. Read man sysctl.d.
2. Look for every file that sets net.core.somaxconn, including the
   files under /usr/lib/sysctl.d, and compare its name with
   80-labtune.conf.
3. The command sysctl has an option that applies all configuration
   files in the same order as the boot. Its output shows which file
   sets which value.

Task 3: the tmpfiles.d file

1. Each line of a tmpfiles.d file has the fields type, path, mode,
   user, group, age and argument. A dash means the default. Read man
   tmpfiles.d, sections Type and Age.
2. The type that creates a directory if it does not exist is a single
   letter. The age field controls the cleanup of old files.
3. The command systemd-tmpfiles applies one configuration file when
   you name it after its create option, and it reports every line it
   cannot parse.

## Solution

1. [sudo] Write the kernel parameters to 80-labtune.conf:

   ```bash
   sudo tee /etc/sysctl.d/80-labtune.conf <<'EOT'
   fs.inotify.max_user_watches = 524288
   net.core.somaxconn = 4096
   kernel.panic = 10
   EOT
   ```

2. [sudo] Find the files that set net.core.somaxconn. The file
   99-zz-legacy.conf sorts after 80-labtune.conf, so its value 128
   wins. Remove only that line from it and keep the
   vm.vfs_cache_pressure line:

   ```bash
   grep -rs somaxconn /etc/sysctl.conf /etc/sysctl.d /run/sysctl.d \
     /usr/lib/sysctl.d
   sudo sed -i '/^[[:space:]]*net\.core\.somaxconn/d' \
     /etc/sysctl.d/99-zz-legacy.conf
   cat /etc/sysctl.d/99-zz-legacy.conf
   ```

3. [sudo] Apply all sysctl files in boot order and check the values:

   ```bash
   sudo sysctl --system
   sysctl fs.inotify.max_user_watches net.core.somaxconn \
     kernel.panic vm.vfs_cache_pressure
   ```

4. [sudo] Write labapp.conf. The variable USER is the task user, who
   owns /run/labapp:

   ```bash
   printf '%s\n' "d /run/labapp 0750 $USER root -" \
     'd /var/tmp/labcache 1777 root root 7d' |
     sudo tee /etc/tmpfiles.d/labapp.conf
   ```

5. [sudo] Apply the file now, which also checks it:

   ```bash
   sudo systemd-tmpfiles --create /etc/tmpfiles.d/labapp.conf
   ls -ld /run/labapp /var/tmp/labcache
   ```

6. [sudo] Reboot. The SSH connection closes; connect again when the
   system is back:

   ```bash
   sudo systemctl reboot
   ```

## Verification

```bash
sysctl fs.inotify.max_user_watches net.core.somaxconn kernel.panic
sysctl vm.vfs_cache_pressure
ls -ld /run/labapp /var/tmp/labcache
labctl grade systemd-11
```

## Explanation

A value written with sysctl -w lasts only until the next boot. At boot
systemd-sysctl reads the *.conf files of /etc/sysctl.d, /run/sysctl.d,
/usr/local/lib/sysctl.d and /usr/lib/sysctl.d, merges them by file
name (a file in /etc replaces one of the same name in /usr/lib) and
applies them sorted by file name. A later file overrides an earlier
one, so 99-zz-legacy.conf sets net.core.somaxconn back to 128 after
80-labtune.conf has set 4096. /etc/sysctl.conf is applied through the
link /etc/sysctl.d/99-sysctl.conf, so it sorts before 99-zz-legacy.conf
as well. The fix removes the stale line and keeps the file, because
its other setting is still needed. Renaming your own file to sort last
would work too, but it hides the conflict instead of removing it.

On Rocky Linux 8 the tuned profile virtual-guest raises
net.core.somaxconn to at least 2048 when tuned starts. tuned then
applies the sysctl files again, so the files still decide the final
value. On Rocky Linux 9 the kernel default is already 4096, which is
why the value 128 from the legacy file is the visible symptom there.

systemd-tmpfiles runs at boot with the create option for every
tmpfiles.d file, so /run/labapp exists again after each boot although
/run is a tmpfs. The line type d creates a directory and sets the mode,
owner and group. The age 7d makes the daily systemd-tmpfiles-clean
timer delete files in /var/tmp/labcache whose access, modification and
change times are all older than seven days. Mode 1777 is the sticky
bit plus full access for everyone, as on /tmp: everyone can create
files, but only the owner of a file can delete it.
