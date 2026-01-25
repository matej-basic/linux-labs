#!/bin/bash

# Storage Lab 02 - LVM Basics (Intermediate)
# Objective: Create Physical Volumes, Volume Groups, and Logical Volumes

cat <<'EOF'
====================================================
LAB: Storage 02 - LVM Basics
====================================================

OBJECTIVE
Create LVM structure with Physical Volumes, Volume Groups, and Logical Volumes.

REQUIREMENTS
1) Create a 100MB loopback image at /tmp/lvm.img
   - Format as ext4 or use for LVM

2) Create a Physical Volume (PV) from the loopback device
   - Initialize LVM on the loopback

3) Create a Volume Group (VG) named 'datavg'
   - Add the PV to this volume group

4) Create a Logical Volume (LV) 'vol0'
   - Size: 80MB
   - In the 'datavg' volume group

5) Format the LV as ext4

6) Mount the LV at /mnt/lvm
   - Permissions: 755

7) Verify with commands:
   - pvs (list physical volumes)
   - vgs (list volume groups)
   - lvs (list logical volumes)
   - df -h /mnt/lvm

CHALLENGE (Optional)
- Extend vol0 to 90MB
- Grow the filesystem to match

USEFUL COMMANDS
- pvcreate, pvs, pvdisplay
- vgcreate, vgs, vgdisplay
- lvcreate, lvs, lvdisplay
- mkfs.ext4
- mount, df, lsblk

Run grading when done:
  sudo labctl grade storage-02
====================================================
EOF
