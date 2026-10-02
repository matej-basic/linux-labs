#!/bin/bash
# Reference solution for storage-04, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /swapfile
# solve: path /etc/sysctl.d/90-swappiness.conf
# solve: reboot
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
dd if=/dev/zero of=/swapfile bs=1M count=512 status=none
chown root:root /swapfile
chmod 600 /swapfile
# Step 2 [sudo]
mkswap /swapfile >/dev/null
swapon -p 10 /swapfile
# Step 3 [sudo]
echo '/swapfile none swap pri=10,nofail 0 0' >> /etc/fstab
systemctl daemon-reload
# Step 4 [sudo]
echo 'vm.swappiness = 20' > /etc/sysctl.d/90-swappiness.conf
sysctl -p /etc/sysctl.d/90-swappiness.conf
# Step 5 [sudo]
rpm -q tuned || dnf -y install tuned
systemctl enable --now tuned
tuned-adm profile throughput-performance
tuned-adm active
# Step 6 [sudo]
sysctl vm.swappiness
