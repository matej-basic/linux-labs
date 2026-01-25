# Solution: users-03

```bash
# Groups
sudo getent group devops || sudo groupadd -g 2000 devops
sudo getent group analytics || sudo groupadd -g 2001 analytics

# bob
sudo id -u bob >/dev/null 2>&1 || sudo useradd -u 1010 -m -g devops -G wheel,analytics -s /bin/bash bob
sudo chown bob:devops /home/bob && sudo chmod 750 /home/bob

# charlie
sudo id -u charlie >/dev/null 2>&1 || sudo useradd -u 1011 -m -g analytics -G wheel -s /bin/bash charlie
sudo chown charlie:analytics /home/charlie && sudo chmod 750 /home/charlie
sudo chage -E 2099-12-31 charlie

# Shared dirs and ACLs
sudo mkdir -p /srv/shared /srv/shared/analytics
sudo chown root:devops /srv/shared && sudo chmod 750 /srv/shared
sudo setfacl -d -m g:devops:rwx /srv/shared
sudo chown root:analytics /srv/shared/analytics && sudo chmod 750 /srv/shared/analytics
sudo setfacl -m u:charlie:rwx /srv/shared/analytics

# Verify
id bob
id charlie
ls -ld /srv/shared /srv/shared/analytics
getfacl /srv/shared | grep default:group:devops || true
getfacl /srv/shared/analytics | grep user:charlie || true

# Grade
sudo labctl grade users-03
```
