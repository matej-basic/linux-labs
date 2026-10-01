#!/bin/bash
# webserver-03 cleanup: remove the lab site, certificate and hosts entry.
# The httpd and mod_ssl packages stay installed (setup does not remove
# them); httpd is stopped and disabled.
systemctl stop httpd &>/dev/null || true
systemctl disable httpd &>/dev/null || true
rm -rf /var/www/lab3
rm -f /etc/httpd/conf.d/lab3.conf
rm -f /etc/pki/tls/certs/lab3.crt
rm -f /etc/pki/tls/private/lab3.key
sed -i '/lab3\.local/d' /etc/hosts
rm -rf /opt/linux-labs/state/webserver-03
exit 0
