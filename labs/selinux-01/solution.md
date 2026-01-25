# Solution: selinux-01

```bash
# Ensure enforcing mode at runtime
sudo setenforce 1
getenforce

# Persist enforcing in config
sudo sed -i -E 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
grep '^SELINUX=' /etc/selinux/config

# Verify policy
sestatus
sestatus | grep 'Loaded policy'

# Grade
sudo labctl grade selinux-01
```
