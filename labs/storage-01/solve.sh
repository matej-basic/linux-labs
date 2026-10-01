#!/bin/bash
# Reference solution for storage-01, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /srv/disk.img
# solve: path /mnt/data
# solve: reboot
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
fallocate -l 100M /srv/disk.img
# Step 2 [sudo]
mkfs.ext4 -q -F /srv/disk.img
# Step 3 [sudo]
mkdir -p /mnt/data
mount -o loop /srv/disk.img /mnt/data
chmod 755 /mnt/data
# Step 4 [sudo]
echo '/srv/disk.img /mnt/data ext4 loop,nofail 0 0' >> /etc/fstab
systemctl daemon-reload
