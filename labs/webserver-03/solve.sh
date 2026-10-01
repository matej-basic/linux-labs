#!/bin/bash
# Reference solution for webserver-03, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /var/www/lab3
# solve: path /etc/httpd/conf.d/lab3.conf
# solve: path /etc/pki/tls/certs/lab3.crt
# solve: path /etc/pki/tls/private/lab3.key
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
dnf -y install httpd mod_ssl >/dev/null

# Step 2 [sudo]
echo "127.0.0.1 lab3.local" >> /etc/hosts

# Step 3 [sudo]
mkdir -p /var/www/lab3/html
echo "Lab 3 HTTPS" > /var/www/lab3/html/index.html

# Step 4 [sudo]
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
	-keyout /etc/pki/tls/private/lab3.key \
	-out /etc/pki/tls/certs/lab3.crt \
	-subj "/C=US/ST=State/L=City/O=Lab/CN=lab3.local" 2>/dev/null

# Step 5 [sudo]
cat > /etc/httpd/conf.d/lab3.conf <<'EOT'
<VirtualHost *:80>
    ServerName lab3.local
    Redirect permanent / https://lab3.local/
</VirtualHost>

<VirtualHost *:443>
    ServerName lab3.local
    DocumentRoot /var/www/lab3/html
    SSLEngine on
    SSLCertificateFile /etc/pki/tls/certs/lab3.crt
    SSLCertificateKeyFile /etc/pki/tls/private/lab3.key
    <Directory /var/www/lab3/html>
        Require all granted
    </Directory>
</VirtualHost>
EOT

# Step 6 [sudo]
httpd -t
systemctl enable --now httpd
