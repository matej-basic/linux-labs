#!/bin/bash
# Reference solution for selinux-02, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /webapp
# solve: path /etc/httpd/conf.d/myapp.conf
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
dnf -y install httpd
systemctl enable httpd

# Step 2 [sudo]
cat > /etc/httpd/conf.d/myapp.conf <<'EOF2'
<VirtualHost *:80>
    ServerName localhost
    DocumentRoot /webapp/www
    <Directory /webapp/www>
        Require all granted
    </Directory>
</VirtualHost>
EOF2

# Step 3 [sudo]
systemctl restart httpd

# Step 4 [sudo]
semanage fcontext -a -t httpd_sys_rw_content_t '/webapp/www(/.*)?'
restorecon -Rv /webapp/www
