#!/bin/bash

# Reset lab state
systemctl stop httpd > /dev/null 2>&1
rm -rf /var/www/lab3
rm -f /etc/httpd/conf.d/lab3.conf
rm -f /etc/pki/tls/certs/lab3.crt
rm -f /etc/pki/tls/private/lab3.key

# Print task description
cat <<'EOF'

====================================================
LAB: Web Servers - HTTPS/SSL (webserver-03)
====================================================

OBJECTIVE:
Configure HTTPS/SSL certificate for Apache, set up
redirect from HTTP to HTTPS, and enable secure
communication on port 443.

REQUIREMENTS:
- Apache httpd must be installed and running
- Create self-signed SSL certificate for lab3.local
- Create directory: /var/www/lab3/html
- Create index.html with content "Lab 3 HTTPS"
- Configure virtual host for lab3.local on port 80
- Configure HTTPS virtual host on port 443
- Redirect HTTP traffic to HTTPS
- Add lab3.local entry to /etc/hosts
- Apache must be restarted to apply changes

NOTES:
- You may use openssl to create self-signed certificate
- The grading script checks only the final state
- Command history is NOT evaluated

When ready, run:
  sudo labctl grade webserver-03

====================================================

EOF

