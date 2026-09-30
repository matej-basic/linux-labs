#!/bin/bash

# Reset lab state
rm -rf /tmp/webfiles /tmp/config

# The apache user normally comes with the httpd package; create it if httpd is not installed
if ! getent passwd apache >/dev/null; then
    useradd -r -U -d /usr/share/httpd -s /sbin/nologin -c "Apache" apache
fi

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
   ├── app/         (Apache runs as the apache user)
   ├── config/      (configuration files, restricted)
   └── data/        (logs and temp data)

2. Create files:
   /tmp/webfiles/app/index.php (owned apache:apache, mode 644)
   /tmp/webfiles/app/upload.php (owned apache:apache, mode 644)
   /tmp/webfiles/config/db.conf (owned root:root, mode 600)
   /tmp/webfiles/data/app.log (owned apache:apache, mode 640)
   /tmp/webfiles/data/error.log (owned root:root, mode 644)

3. Set directory permissions:
   /tmp/webfiles/          (owned root:root, mode 755)
   /tmp/webfiles/app/      (owned apache:apache, mode 755)
   /tmp/webfiles/config/   (owned root:root, mode 700)
   /tmp/webfiles/data/     (owned apache:apache, mode 755)

NOTES:
- Use chmod, chown to fix permissions.
- The apache user has already been created for you.
- Focus on principle of least privilege.

When ready, run:
  sudo labctl grade files-02

====================================================

EOF
