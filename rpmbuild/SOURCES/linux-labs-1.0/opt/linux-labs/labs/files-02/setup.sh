#!/bin/bash

# Reset lab state
rm -rf /tmp/webfiles /tmp/config

# Print task description
cat <<'EOF'

====================================================
LAB: File Permissions and Ownership (files-02)
====================================================

OBJECTIVE:
Fix file and directory permissions and ownership to match
a realistic web application directory structure.

TASKS:

1. Create directory structure:
   /tmp/webfiles/
   ├── app/         (Apache runs as www-data user)
   ├── config/      (configuration files, restricted)
   └── data/        (logs and temp data)

2. Create files:
   /tmp/webfiles/app/index.php (owned www-data:www-data, mode 644)
   /tmp/webfiles/app/upload.php (owned www-data:www-data, mode 644)
   /tmp/webfiles/config/db.conf (owned root:root, mode 600)
   /tmp/webfiles/data/app.log (owned www-data:www-data, mode 640)
   /tmp/webfiles/data/error.log (owned root:root, mode 644)

3. Set directory permissions:
   /tmp/webfiles/          (owned root:root, mode 755)
   /tmp/webfiles/app/      (owned www-data:www-data, mode 755)
   /tmp/webfiles/config/   (owned root:root, mode 700)
   /tmp/webfiles/data/     (owned www-data:www-data, mode 755)

NOTES:
- Use chmod, chown to fix permissions.
- www-data user exists on most Linux systems.
- Focus on principle of least privilege.

When ready, run:
  sudo labctl grade files-02

====================================================

EOF
