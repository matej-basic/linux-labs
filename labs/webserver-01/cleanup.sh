#!/bin/bash

# Print information about cleanup
echo "Cleaning up Web Servers - Apache Installation (webserver-01) lab environment..."

systemctl stop httpd > /dev/null 2>&1
systemctl disable httpd > /dev/null 2>&1
dnf remove -y httpd > /dev/null 2>&1

# End of cleanup message
echo "Cleanup completed."