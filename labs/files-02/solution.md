# files-02: Web directory permissions and ownership

## Solution

1. [sudo] Create the directories:

   ```bash
   sudo mkdir -p /tmp/webfiles/app /tmp/webfiles/config \
     /tmp/webfiles/data
   ```

2. [sudo] Create the empty files:

   ```bash
   sudo touch /tmp/webfiles/app/index.php /tmp/webfiles/app/upload.php
   sudo touch /tmp/webfiles/config/db.conf
   sudo touch /tmp/webfiles/data/app.log /tmp/webfiles/data/error.log
   ```

3. [sudo] Set owner and mode on the directories:

   ```bash
   sudo chown root:root /tmp/webfiles /tmp/webfiles/config
   sudo chown apache:apache /tmp/webfiles/app /tmp/webfiles/data
   sudo chmod 755 /tmp/webfiles /tmp/webfiles/app /tmp/webfiles/data
   sudo chmod 700 /tmp/webfiles/config
   ```

4. [sudo] Set owner and mode on the files:

   ```bash
   sudo chown apache:apache /tmp/webfiles/app/index.php \
     /tmp/webfiles/app/upload.php /tmp/webfiles/data/app.log
   sudo chown root:root /tmp/webfiles/config/db.conf \
     /tmp/webfiles/data/error.log
   sudo chmod 644 /tmp/webfiles/app/index.php \
     /tmp/webfiles/app/upload.php /tmp/webfiles/data/error.log
   sudo chmod 640 /tmp/webfiles/data/app.log
   sudo chmod 600 /tmp/webfiles/config/db.conf
   ```

## Verification

```bash
sudo ls -lR /tmp/webfiles
labctl grade files-02
```

## Explanation

Files created with sudo belong to root, so the root-owned entries
already match and only the apache entries need chown. Directories
created by mkdir get mode 755 from the default umask 022, files from
touch get 644, and the tighter or looser modes need an explicit chmod.

The config directory is mode 700, so even a listing of it needs sudo.
The grader runs as root, so it can look inside it.
