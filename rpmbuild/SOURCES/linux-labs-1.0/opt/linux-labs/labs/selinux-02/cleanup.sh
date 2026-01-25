#!/bin/bash
rm -rf /webapp
sudo rm -f /etc/httpd/conf.d/myapp.conf

# Ensure selinux is in permissive mode
sudo setenforce 0 2>/dev/null || true
sudo sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config 2>/dev/null || true

# Remove apache web server if installed
sudo dnf remove -y httpd >/dev/null 2>&1 || true

# Print cleanup confirmation
echo "Cleanup complete. SELinux set to permissive mode."