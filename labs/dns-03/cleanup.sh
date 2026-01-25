#!/bin/bash

# Print information about cleanup
echo "Cleaning up DNS - DNSSEC & Replication (dns-03) lab environment..."

systemctl stop named > /dev/null 2>&1
systemctl disable named > /dev/null 2>&1
dnf remove -y bind bind-utils > /dev/null 2>&1
rm -rf /var/named/labsecure.com.zone* /var/named/K* > /dev/null 2>&1

# End of cleanup message
echo "Cleanup completed."
