#!/bin/bash
# SELinux Lab 01: Cleanup

# Set SELinux back to permissive mode
sudo setenforce 0 2>/dev/null || true
sudo sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config 2>/dev/null || true

echo "Cleanup complete. SELinux set to permissive mode."
