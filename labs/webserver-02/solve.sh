#!/bin/bash
# Reference solution for webserver-02, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /var/www/lab2
# solve: path /etc/httpd/conf.d/lab2.conf
# solve: package httpd
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
dnf -y install httpd
systemctl enable --now httpd

# Step 2 [sudo]
mkdir -p /var/www/lab2/html
echo "Welcome to Lab 2" | tee /var/www/lab2/html/index.html

# Step 3 [sudo]
echo "127.0.0.1 lab2.local" | tee -a /etc/hosts

# Step 4 [sudo]
tee /etc/httpd/conf.d/lab2.conf > /dev/null <<'CONF'
<VirtualHost *:80>
    ServerName lab2.local
    DocumentRoot /var/www/lab2/html
    <Directory /var/www/lab2/html>
        Require all granted
    </Directory>
</VirtualHost>
CONF

# Step 5 [sudo]
httpd -t
systemctl restart httpd
