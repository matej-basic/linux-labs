# selinux-01: SELinux enforcing mode

## Hints

1. The mode of the running kernel and the mode at boot are two separate
   settings, and both are graded.
2. See man setenforce for the runtime change. The boot setting is in
   the file /etc/selinux/config, described in man selinux_config.
3. In that file the SELINUX variable takes the value enforcing. Leave
   SELINUXTYPE alone. Run sestatus to check the mode and the loaded
   policy name.

## Solution

1. [sudo] Switch the running system to enforcing mode:

   ```bash
   sudo setenforce 1
   getenforce
   ```

2. [sudo] Make the mode persistent in the configuration file:

   ```bash
   sudo sed -i -E 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
   grep '^SELINUX' /etc/selinux/config
   ```

3. [user] Confirm that SELinux is enabled and the targeted policy is
   loaded:

   ```bash
   sestatus
   ```

## Verification

```bash
labctl grade selinux-01
```

## Explanation

setenforce changes the mode of the running kernel only, so the system
would boot permissive again without the change in /etc/selinux/config.
The config edit alone does not change the running mode. Both are
graded.

In enforcing mode the policy blocks violations and logs them. In
permissive mode violations are only logged. Disabled turns SELinux off
and needs a full relabel on the way back, which is why this lab never
asks for it.
