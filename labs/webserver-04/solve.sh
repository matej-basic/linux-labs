#!/bin/bash
# Reference solution for webserver-04, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: package nginx
# solve: path /etc/nginx/conf.d/app.lab.local.conf
# solve: path /etc/pki/tls/certs/app.lab.local.crt
# solve: path /etc/pki/tls/private/app.lab.local.key
# solve: path /srv/webapp
# solve: path /etc/systemd/system/webapp.service
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
rpm -q nginx >/dev/null || dnf -y install nginx >/dev/null

# Step 2 [sudo]
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
	-keyout /etc/pki/tls/private/app.lab.local.key \
	-out /etc/pki/tls/certs/app.lab.local.crt \
	-subj "/CN=app.lab.local" \
	-addext "subjectAltName=DNS:app.lab.local" 2>/dev/null
chown root:root /etc/pki/tls/private/app.lab.local.key
chmod 0600 /etc/pki/tls/private/app.lab.local.key

# Step 3 [sudo]
cat > /etc/nginx/conf.d/app.lab.local.conf <<'EOT'
server {
    listen 80;
    server_name app.lab.local;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name app.lab.local;
    ssl_certificate /etc/pki/tls/certs/app.lab.local.crt;
    ssl_certificate_key /etc/pki/tls/private/app.lab.local.key;

    location / {
        proxy_pass http://127.0.0.1:8081;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOT
nginx -t 2>/dev/null

# Step 4 [sudo]
setsebool -P httpd_can_network_connect on

# Step 5 [sudo]
systemctl enable --now nginx

# Step 6 [sudo]
firewall-cmd --add-service=http --add-service=https >/dev/null
firewall-cmd --permanent --add-service=http --add-service=https >/dev/null

# Step 7 [user]
run_as_student <<'STEPS'
curl -sk --resolve app.lab.local:443:127.0.0.1 https://app.lab.local/ |
	grep -q 'webapp backend is up'
curl -sk --resolve app.lab.local:443:127.0.0.1 \
	https://app.lab.local/headers | grep -qi 'x-forwarded-proto: https'
curl -sI --resolve app.lab.local:80:127.0.0.1 http://app.lab.local/a |
	grep -q '301'
STEPS
