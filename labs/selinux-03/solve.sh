#!/bin/bash
# Reference solution for selinux-03, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /webapp
# solve: path /etc/httpd/conf.d/lab-port.conf
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
semanage port -l | grep -w 8081 || true
ls -dZ /webapp/porttest
# Step 2 [sudo]
semanage port -a -t http_port_t -p tcp 8081 \
	|| semanage port -m -t http_port_t -p tcp 8081
# Step 3 [sudo]
semanage fcontext -a -t httpd_sys_content_t "/webapp/porttest(/.*)?"
restorecon -Rv /webapp/porttest
# Step 4 [sudo]
systemctl start httpd
# Step 5 [user]
run_as_student 'curl -sf http://localhost:8081/'
