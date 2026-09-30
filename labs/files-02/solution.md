# Files 02 Solution

Create structure, ownership, and modes:

```bash
# Directories
sudo mkdir -p /tmp/webfiles/app /tmp/webfiles/config /tmp/webfiles/data

# Ownership and directory perms
sudo chown root:root /tmp/webfiles
sudo chmod 755 /tmp/webfiles

sudo chown apache:apache /tmp/webfiles/app /tmp/webfiles/data
sudo chmod 755 /tmp/webfiles/app /tmp/webfiles/data

sudo chown root:root /tmp/webfiles/config
sudo chmod 700 /tmp/webfiles/config

# Files
sudo tee /tmp/webfiles/app/index.php >/dev/null <<<''
sudo tee /tmp/webfiles/app/upload.php >/dev/null <<<''
sudo tee /tmp/webfiles/config/db.conf >/dev/null <<<''
sudo tee /tmp/webfiles/data/app.log >/dev/null <<<''
sudo tee /tmp/webfiles/data/error.log >/dev/null <<<''

# File ownership and perms
sudo chown apache:apache /tmp/webfiles/app/index.php /tmp/webfiles/app/upload.php /tmp/webfiles/data/app.log
sudo chmod 644 /tmp/webfiles/app/index.php /tmp/webfiles/app/upload.php
sudo chmod 640 /tmp/webfiles/data/app.log

sudo chown root:root /tmp/webfiles/config/db.conf /tmp/webfiles/data/error.log
sudo chmod 600 /tmp/webfiles/config/db.conf
sudo chmod 644 /tmp/webfiles/data/error.log
```

Verify:
```bash
sudo stat -c '%U:%G %a %n' /tmp/webfiles /tmp/webfiles/app /tmp/webfiles/config /tmp/webfiles/data
sudo stat -c '%U:%G %a %n' /tmp/webfiles/app/index.php /tmp/webfiles/app/upload.php /tmp/webfiles/config/db.conf /tmp/webfiles/data/app.log /tmp/webfiles/data/error.log
sudo labctl grade files-02
```
