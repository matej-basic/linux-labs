#!/bin/bash
# Reference solution for storage-02, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /tmp/lvm.img
# solve: path /mnt/lvm
# solve: path /dev/datavg
# solve: path /dev/mapper/datavg-vol0
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
fallocate -l 100M /tmp/lvm.img
LOOP=$(losetup --find --show /tmp/lvm.img)

# Steps 2 to 4 [sudo]
pvcreate "$LOOP"
vgcreate datavg "$LOOP"
lvcreate -L 80M -n vol0 datavg

# Step 5 [sudo]
mkfs.ext4 /dev/datavg/vol0

# Step 6 [sudo]
mkdir -p /mnt/lvm
mount /dev/datavg/vol0 /mnt/lvm
chmod 755 /mnt/lvm
