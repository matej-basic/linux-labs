# Files 03 Solution

Apply special perms, ACLs, and backup:

```bash
# Groups/users
sudo groupadd -g 3000 developers 2>/dev/null || true
sudo useradd -u 1001 -g developers alice 2>/dev/null || true

# Directories
sudo mkdir -p /srv/secure/bin /srv/secure/shared /srv/secure/tmp
sudo chown root:root /srv/secure
sudo chmod 755 /srv/secure

# deploy.sh with setuid
sudo tee /srv/secure/bin/deploy.sh >/dev/null <<'EOF'
#!/bin/bash
echo "Deployment tool"
EOF
sudo chmod 4755 /srv/secure/bin/deploy.sh
sudo chown root:root /srv/secure/bin/deploy.sh

# shared dir setgid for developers
sudo chown root:developers /srv/secure/shared
sudo chmod 2770 /srv/secure/shared
sudo setfacl -m g:developers:rwx /srv/secure/shared

# tmp dir sticky
sudo chown root:root /srv/secure/tmp
sudo chmod 1777 /srv/secure/tmp
sudo setfacl -m u:alice:rwx /srv/secure/tmp

# Backup
sudo tar -czpf /tmp/backup.tar.gz /srv/secure
```

Verify:
```bash
sudo stat -c '%U:%G %a %n' /srv/secure /srv/secure/bin/deploy.sh /srv/secure/shared /srv/secure/tmp
sudo getfacl /srv/secure/shared /srv/secure/tmp
tar -tzf /tmp/backup.tar.gz | head
sudo labctl grade files-03
```
