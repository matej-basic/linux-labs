# selinux-01: SELinux enforcing mode

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
