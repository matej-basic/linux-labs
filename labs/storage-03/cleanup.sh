#!/bin/bash

# Storage Lab 03 - Cleanup Script
# Removes all LVM snapshot resources created during the lab

echo "Cleanup: Storage Lab 03"
echo ""

# Unmount filesystems
if mountpoint -q /mnt/original; then
    echo -n "Unmounting /mnt/original... "
    umount /mnt/original 2>/dev/null && echo "done" || echo "failed"
fi

if mountpoint -q /mnt/snap1; then
    echo -n "Unmounting /mnt/snap1... "
    umount /mnt/snap1 2>/dev/null && echo "done" || echo "failed"
fi

# Remove mount points
if [[ -d /mnt/original ]]; then
    echo -n "Removing mount point /mnt/original... "
    rmdir /mnt/original 2>/dev/null && echo "done" || echo "skipped"
fi

if [[ -d /mnt/snap1 ]]; then
    echo -n "Removing mount point /mnt/snap1... "
    rmdir /mnt/snap1 2>/dev/null && echo "done" || echo "skipped"
fi

# Remove snapshot
if lvs /dev/snapvg/snap1 2>/dev/null; then
    echo -n "Removing snapshot 'snap1'... "
    lvremove -f /dev/snapvg/snap1 2>/dev/null && echo "done" || echo "failed"
fi

# Remove original LV
if lvs /dev/snapvg/original 2>/dev/null; then
    echo -n "Removing Logical Volume 'original'... "
    lvremove -f /dev/snapvg/original 2>/dev/null && echo "done" || echo "failed"
fi

# Remove VG
if vgs snapvg 2>/dev/null; then
    echo -n "Removing Volume Group 'snapvg'... "
    vgremove -f snapvg 2>/dev/null && echo "done" || echo "failed"
fi

# Remove PV (find loopback device)
if pvs 2>/dev/null | grep -q "loop"; then
    LOOP_DEV=$(pvs 2>/dev/null | grep "loop" | awk '{print $1}')
    if [[ -n "$LOOP_DEV" ]]; then
        echo -n "Removing Physical Volume ($LOOP_DEV)... "
        pvremove -ff "$LOOP_DEV" 2>/dev/null && echo "done" || echo "skipped"
    fi
fi

# Detach loopback device
if losetup /dev/loop0 2>/dev/null | grep -q "snap.img"; then
    echo -n "Detaching loopback device /dev/loop0... "
    losetup -d /dev/loop0 2>/dev/null && echo "done" || echo "skipped"
fi

# Remove snap.img
if [[ -f /tmp/snap.img ]]; then
    echo -n "Removing /tmp/snap.img... "
    rm -f /tmp/snap.img && echo "done" || echo "failed"
fi

echo ""
echo "Cleanup completed."
