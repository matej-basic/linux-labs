# Solution: users-02

```bash
# Group
sudo getent group contractors || sudo groupadd contractors

# dave
sudo id -u dave >/dev/null 2>&1 || sudo useradd -m -g contractors -s /bin/bash dave
echo 'contractor123' | sudo passwd --stdin dave
sudo chage -M 30 dave

# eve
sudo id -u eve >/dev/null 2>&1 || sudo useradd -m -g contractors -s /bin/bash eve
echo 'eve-pass' | sudo passwd --stdin eve
sudo chage -E 2026-01-31 eve
sudo chage -M -1 eve

# Resource limits
sudo bash -c 'cat > /etc/security/limits.d/70-contractors.conf <<EOF
contractors soft nofile 1024
contractors hard nofile 1024
contractors soft nproc 512
contractors hard nproc 512
EOF'

# Password policy in login.defs
sudo sed -i -E 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/; s/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   1/; s/^PASS_WARN_AGE.*/PASS_WARN_AGE   14/' /etc/login.defs

# Verify
chage -l dave
chage -l eve
cat /etc/security/limits.d/70-contractors.conf
grep -E 'PASS_MAX_DAYS|PASS_MIN_DAYS|PASS_WARN_AGE' /etc/login.defs

# Grade
sudo labctl grade users-02
```
