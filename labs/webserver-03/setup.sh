#!/bin/bash
# webserver-03 setup: remove leftovers of an earlier run and stop httpd,
# so the student starts without the site. Prints nothing on success.
set -eu

systemctl stop httpd &>/dev/null || true
rm -rf /var/www/lab3
rm -f /etc/httpd/conf.d/lab3.conf
rm -f /etc/pki/tls/certs/lab3.crt
rm -f /etc/pki/tls/private/lab3.key
sed -i '/lab3\.local/d' /etc/hosts
