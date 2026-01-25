#!/bin/bash

# Storage Lab 03 - LVM Snapshots (Advanced)
# Objective: Create and use LVM snapshots for backup and recovery

cat <<'EOF'
====================================================
LAB: Storage 03 - LVM Snapshots
====================================================

OBJECTIVE
Create LVM snapshots and demonstrate backup/recovery capabilities.

REQUIREMENTS
1) Create a 150MB loopback image at /tmp/snap.img

2) Set up LVM infrastructure
   - Physical Volume from the loopback
   - Volume Group named 'snapvg'

3) Create Logical Volume 'original'
   - Size: 100MB
   - Format as ext4
   - Mount at /mnt/original

4) Create test data in 'original' volume
   - Create some files with known content

5) Create a snapshot 'snap1' of 'original'
   - Size: 20MB (snapshot overhead)

6) Demonstrate snapshot behavior
   - Modify files in 'original'
   - Show that snapshot preserves pre-snapshot state

7) Show snapshot merging or rollback
   - Demonstrate snapshot merge capabilities

USEFUL COMMANDS
- pvcreate, vgcreate, lvcreate
- lvcreate --snapshot
- lvs, lvdisplay
- lvconvert (merge snapshots)
- mount, umount
- df, dd (write test data)

Run grading when done:
  sudo labctl grade storage-03
====================================================
EOF
echo ""
