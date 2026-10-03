#!/bin/bash
# Reference solution for webserver-06, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: package httpd
# solve: package php-fpm
# solve: package policycoreutils-python-utils
# solve: path /srv/phpapp
# solve: path /etc/php-fpm.d/intranet.conf
# solve: path /etc/httpd/conf.d/phpapp.conf
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
rpm -q httpd >/dev/null || dnf -y install httpd >/dev/null
rpm -q php-fpm >/dev/null || dnf -y install php-fpm >/dev/null
rpm -q policycoreutils-python-utils >/dev/null ||
	dnf -y install policycoreutils-python-utils >/dev/null

# Step 2 [sudo]
tee /etc/php-fpm.d/intranet.conf >/dev/null <<'CONF'
[intranet]
user = phpapp
group = phpapp
listen = /run/php-fpm/intranet.sock
listen.acl_users = apache
pm = ondemand
pm.max_children = 5
pm.process_idle_timeout = 10s
php_admin_value[memory_limit] = 64M
php_admin_value[error_log] = /var/log/php-fpm/intranet-error.log
php_admin_flag[log_errors] = on
CONF
php-fpm -t

# Step 3 [sudo]
tee /etc/httpd/conf.d/phpapp.conf >/dev/null <<'CONF'
<VirtualHost *:80>
  ServerName servera
  DocumentRoot /srv/phpapp/public
  <Directory /srv/phpapp/public>
    Options None
    AllowOverride None
    Require all granted
  </Directory>
  <FilesMatch \.php$>
    SetHandler proxy:unix:/run/php-fpm/intranet.sock|fcgi://localhost
  </FilesMatch>
</VirtualHost>
CONF
httpd -t

# Step 4 [sudo]
semanage fcontext -a -t httpd_sys_content_t '/srv/phpapp/public(/.*)?'
restorecon -Rv /srv/phpapp/public

# Step 5 [sudo]
systemctl enable --now php-fpm httpd

# Step 6 [sudo]
firewall-cmd --add-service=http
firewall-cmd --permanent --add-service=http

# Step 7 [user]
uid=$(id -u phpapp)
for _ in 1 2 3 4 5; do
	run_as_student "curl -s http://localhost/ | grep '^effective_uid=$uid\$'" && break
	sleep 1
done
