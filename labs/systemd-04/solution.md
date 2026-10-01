# systemd-04: Default boot target

## Solution

1. [user] Check the current default target. It is graphical.target
   after setup:

   ```bash
   systemctl get-default
   ```

2. [sudo] Set the default to text mode:

   ```bash
   sudo systemctl set-default multi-user.target
   ```

3. [sudo] Reboot to confirm the system boots into it:

   ```bash
   sudo systemctl reboot
   ```

## Verification

After logging in again:

```bash
systemctl get-default
systemctl is-active multi-user.target
labctl grade systemd-04
```

Do not switch the default back. `sudo labctl reset systemd-04`
restores the original default.

## Explanation

systemctl isolate multi-user.target switches the running system right
now: it starts everything multi-user.target needs and stops the rest.
It changes nothing on disk, so systemctl get-default still prints
graphical.target and the next boot goes back to it.

systemctl set-default multi-user.target only changes the symlink
/etc/systemd/system/default.target. The running system stays as it is
until the next boot. That is why the grader needs both: the new
default, and a reboot that proves it works. The reboot is detected by
comparing /proc/sys/kernel/random/boot_id with the value recorded when
the lab started.

The old SysV runlevels map to targets: runlevel 3 is multi-user.target
(text login, networking, all services) and runlevel 5 is
graphical.target (multi-user plus a display manager).
systemctl list-units --type=target shows which targets are active now.
