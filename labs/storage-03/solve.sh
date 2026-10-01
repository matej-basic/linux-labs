#!/bin/bash
# Reference solution for storage-03, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /tmp/snap.img
# solve: path /mnt/original
# solve: path /mnt/snap1
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
fallocate -l 150M /tmp/snap.img
LOOP=$(losetup --find --show /tmp/snap.img)

# Step 2 [sudo]
pvcreate "$LOOP"
vgcreate snapvg "$LOOP"

# Step 3 [sudo]
lvcreate -L 100M -n original snapvg
udevadm settle
mkfs.ext4 -q /dev/snapvg/original
mkdir -p /mnt/original /mnt/snap1
mount /dev/snapvg/original /mnt/original

# Step 4 [sudo]
echo "before snapshot" > /mnt/original/before.txt

# Step 5 [sudo]
lvcreate -L 20M -s -n snap1 /dev/snapvg/original
udevadm settle
mount /dev/snapvg/snap1 /mnt/snap1

# Step 6 [sudo]
echo "after snapshot" > /mnt/original/testfile.txt
