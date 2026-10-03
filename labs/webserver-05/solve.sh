#!/bin/bash
# Reference solution for webserver-05, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: package httpd
# solve: package policycoreutils-python-utils
# solve: path /srv/intranet
# solve: path /etc/httpd/conf.d/intranet.conf
# solve: path /etc/httpd/conf.d/status.conf
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [user]: nothing answers on port 80
run_as_student '! curl -sS http://localhost/ >/dev/null 2>&1'

# Step 2 [sudo]: the journal names the port, the configuration test
# passes
if systemctl is-active --quiet httpd; then exit 1; fi
journalctl -u httpd -n 20 --no-pager | grep 'could not bind to address.*:8089' >/dev/null
httpd -t 2>/dev/null
grep -r Listen /etc/httpd/conf /etc/httpd/conf.d | grep 'status.conf:Listen 8089' >/dev/null
semanage port -l | grep -w http_port_t >/dev/null

# Step 3 [sudo]
semanage port -a -t http_port_t -p tcp 8089
systemctl enable --now httpd
systemctl is-active httpd

# Step 4 [user]: 403 and the test page
run_as_student <<'STEPS'
test "$(curl -s -o /dev/null -w '%{http_code}' http://localhost/)" = 403
STEPS

# Step 5 [sudo]
tail -n 5 /var/log/httpd/intranet_error.log
ls -ldZ /srv/intranet /srv/intranet/index.html /var/www/html

# Step 6 [sudo]
chmod 0644 /srv/intranet/index.html

# Step 7 [sudo]. ausearch reads standard input when it is not a
# terminal, as under test-lab.sh, so --input-logs makes it read the log.
sleep 1
ausearch --input-logs -m AVC -ts recent | grep admin_home_t >/dev/null
semanage fcontext -a -t httpd_sys_content_t '/srv/intranet(/.*)?'
restorecon -Rv /srv/intranet
matchpathcon /srv/intranet /srv/intranet/index.html
run_as_student "curl -s http://localhost/ | grep 'Welcome to the lab intranet'"

# Step 8 [sudo]
firewall-cmd --add-service=http
firewall-cmd --permanent --add-service=http
firewall-cmd --list-services

# Step 9 [user] runs on the workstation; here the request goes to the
# address of the default-route interface instead
dev=$(ip -4 route show default |
	awk '{ for (i = 1; i < NF; i++) if ($i == "dev") { print $(i + 1); exit } }')
addr=$(ip -4 -o addr show dev "$dev" | awk '{ split($4, a, "/"); print a[1]; exit }')
run_as_student "curl -s http://$addr/ | grep 'Welcome to the lab intranet'"
