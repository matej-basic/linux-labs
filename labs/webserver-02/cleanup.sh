#!/bin/bash

# Print information about cleanup
echo "Cleaning up Web Servers - Virtual Hosts (webserver-02) lab environment..."

systemctl stop httpd 2>/dev/null
rm -rf /var/www/lab2
rm -f /etc/httpd/conf.d/lab2.conf
sed -i '/lab2.local/d' /etc/hosts

# End of cleanup message
echo "Cleanup completed."