# Solution: users-01

```bash
# Group
sudo getent group project || sudo groupadd project

# alice user
sudo id -u alice >/dev/null 2>&1 || sudo useradd -m -g project -G wheel -s /bin/bash alice

# svcapp system user
sudo id -u svcapp >/dev/null 2>&1 || sudo useradd -r -M -d /srv/svcapp -g project -s /usr/sbin/nologin svcapp
sudo mkdir -p /srv/svcapp && sudo chown svcapp:project /srv/svcapp && sudo chmod 750 /srv/svcapp

# shared dir
sudo mkdir -p /srv/project && sudo chown root:project /srv/project && sudo chmod 2775 /srv/project

# Verify
id alice
id svcapp
ls -ld /home/alice /srv/svcapp /srv/project

# Grade
sudo labctl grade users-01
```
