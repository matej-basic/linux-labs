#!/bin/bash

# Storage Lab 01 - Cleanup Script
# Removes all resources created during the lab

echo "Cleanup: Storage Lab 01"
echo ""

# Unmount if mounted
if mountpoint -q /mnt/data; then
    echo -n "Unmounting /mnt/data... "
    umount /mnt/data 2>/dev/null && echo "done" || echo "failed"
fi

# Remove mount point if empty
if [[ -d /mnt/data ]]; then
    echo -n "Removing mount point /mnt/data... "
    rmdir /mnt/data 2>/dev/null && echo "done" || echo "skipped"
fi

# Remove disk image
if [[ -f /tmp/disk.img ]]; then
    echo -n "Removing /tmp/disk.img... "
    rm -f /tmp/disk.img && echo "done" || echo "failed"
fi

# Remove fstab entry
if grep -q "/mnt/data" /etc/fstab; then
    echo -n "Removing /etc/fstab entry... "
    sed -i '\|/mnt/data|d' /etc/fstab && echo "done" || echo "failed"
fi

echo ""
echo "Cleanup completed."
