#!/bin/bash

# Storage Lab 01 - Loopback Filesystem (Beginner)
# Objective: Create a loopback filesystem, format it, mount it persistently

cat <<'EOF'
====================================================
LAB: Storage 01 - Loopback Filesystem
====================================================

OBJECTIVE
Create a loopback filesystem and mount it persistently.

REQUIREMENTS
1) Create a 100MB disk image at /tmp/disk.img
   - Use dd or fallocate to create the file

2) Format the image as ext4 filesystem
   - Make it ext4-formatted

3) Mount the image at /mnt/data
   - Use mount with loop option
   - Set permissions to 755

4) Make the mount persistent
   - Add entry to /etc/fstab
   - Should survive reboot

5) Verify the setup
   - Check with df -h and lsblk

USEFUL COMMANDS
- dd, fallocate (create image file)
- mkfs.ext4 (format filesystem)
- mount (attach filesystem)
- chmod (change permissions)
- blkid (find UUID)
- /etc/fstab (persistent mounts)
- df, lsblk, mount (verify)

Run grading when done:
  sudo labctl grade storage-01
====================================================
EOF
