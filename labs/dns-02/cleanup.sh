#!/bin/bash

# Print information about cleanup
echo "Cleaning up DNS - Zone Configuration (dns-02) lab environment..."

systemctl stop named > /dev/null 2>&1
systemctl disable named > /dev/null 2>&1
dnf remove -y bind bind-utils > /dev/null 2>&1
rm -rf /var/named/labdomain.com.zone > /dev/null 2>&1

# End of cleanup message
echo "Cleanup completed."
