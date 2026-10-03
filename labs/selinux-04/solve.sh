#!/bin/bash
# Reference solution for selinux-04, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: package httpd
# solve: package policycoreutils-python-utils
# solve: path /home/webdev
# solve: path /etc/httpd/conf.d/lab-userdir.conf
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [user]
run_as_student 'curl -s http://localhost/~webdev/ >/dev/null'
# Step 2 [sudo]
tail -n 5 /var/log/httpd/error_log
ls -ld /home/webdev /home/webdev/public_html
# Step 3 [sudo]
chmod o=x /home/webdev
chmod o=rx /home/webdev/public_html
# Step 4 [user]
run_as_student 'curl -s http://localhost/~webdev/ >/dev/null'
# Step 5 [sudo]. ausearch reads standard input when it is not a
# terminal, as under test-lab.sh, so --input-logs makes it read the log.
# The denial must be there and audit2why must name the boolean.
sleep 1
ausearch --input-logs -m AVC -ts recent
ausearch --input-logs -m AVC -ts recent | audit2why |
	grep httpd_enable_homedirs
# Step 6 [sudo]
setsebool -P httpd_enable_homedirs on
getsebool httpd_enable_homedirs
semanage boolean -l | grep httpd_enable_homedirs
# Step 7 [sudo]
systemctl enable --now httpd
# Step 8 [user]
run_as_student 'curl -sf http://localhost/~webdev/ | grep "webdev personal page"'
