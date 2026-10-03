#!/bin/bash
# Reference solution for webserver-08, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: package httpd
# solve: package httpd-tools
# solve: path /etc/httpd/lab.htpasswd
# solve: path /etc/httpd/conf.d/lab-access.conf
# solve: path /var/www/html/private
# solve: path /var/www/html/admin
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
rpm -q httpd >/dev/null || dnf -y install httpd >/dev/null

# Step 2 [sudo]
htpasswd -c -B -b /etc/httpd/lab.htpasswd alice redwood42
htpasswd -B -b /etc/httpd/lab.htpasswd bob seashell17
chown root:apache /etc/httpd/lab.htpasswd
chmod 0640 /etc/httpd/lab.htpasswd

# Step 3 [sudo]
tee /etc/httpd/conf.d/lab-access.conf >/dev/null <<'CONF'
<Directory "/var/www/html/private">
    AuthType Basic
    AuthName "Private area"
    AuthUserFile /etc/httpd/lab.htpasswd
    Require valid-user
</Directory>

<Directory "/var/www/html/admin">
    Require ip 127.0.0.1 ::1
</Directory>
CONF

# Step 4 [sudo]
apachectl configtest
systemctl enable --now httpd

# Step 5 [sudo]
firewall-cmd --add-service=http
firewall-cmd --permanent --add-service=http

# Step 6 [user]
for _ in 1 2 3 4 5; do
	run_as_student 'curl -s -u alice:redwood42 http://127.0.0.1/private/ | grep -q PRIVATE-PAGE-OK' && break
	sleep 1
done
run_as_student <<'STEPS'
dev=$(ip -4 route show default | awk '{ print $5; exit }')
addr=$(ip -4 -o addr show dev "$dev" | awk '{ split($4, a, "/"); print a[1]; exit }')
test "$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1/private/)" = 401
curl -s -u bob:seashell17 http://127.0.0.1/private/ | grep -q PRIVATE-PAGE-OK
curl -s http://127.0.0.1/admin/ | grep -q ADMIN-PAGE-OK
test "$(curl -s -o /dev/null -w '%{http_code}' "http://$addr/admin/")" = 403
STEPS
