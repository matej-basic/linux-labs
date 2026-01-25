#!/bin/bash

# Reset lab state
systemctl stop httpd >/dev/null 2>&1
rm -rf /var/www/lab2
rm -f /etc/httpd/conf.d/lab2.conf

# Print task description
cat <<'EOF'

====================================================
LAB: Web Servers - Virtual Hosts (webserver-02)
====================================================

OBJECTIVE:
Configure an Apache virtual host to serve content
from /var/www/lab2/html for domain lab2.local.

REQUIREMENTS:
- Apache httpd must be installed and running
- Create directory: /var/www/lab2/html
- Create index.html with content "Welcome to Lab 2"
- Configure virtual host for lab2.local
- Add lab2.local entry to /etc/hosts
- Virtual host should serve from /var/www/lab2/html
- Apache must be restarted to apply changes

NOTES:
- You may use any valid Linux commands
- The grading script checks only the final state
- Command history is NOT evaluated

When ready, run:
  sudo labctl grade webserver-02

====================================================

EOF

