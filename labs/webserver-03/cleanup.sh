#!/bin/bash

# Print information about cleanup
echo "Cleaning up Web Servers - SSL Configuration (webserver-03) lab environment..."

systemctl stop httpd &>/dev/null || true
systemctl disable httpd &>/dev/null || true
rm -rf /var/www/lab3
rm -f /etc/httpd/conf.d/lab3.conf
rm -f /etc/pki/tls/certs/lab3.crt
rm -f /etc/pki/tls/private/lab3.key
sed -i '/lab3.local/d' /etc/hosts

# End of cleanup message
echo "Cleanup completed."