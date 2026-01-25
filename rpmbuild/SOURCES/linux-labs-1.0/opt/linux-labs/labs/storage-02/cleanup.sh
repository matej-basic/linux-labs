#!/bin/bash

# Storage Lab 02 - Cleanup Script
# Removes all LVM resources created during the lab

echo "Cleanup: Storage Lab 02"
echo ""

# Unmount filesystem if mounted
if mountpoint -q /mnt/lvm; then
    echo -n "Unmounting /mnt/lvm... "
    umount /mnt/lvm 2>/dev/null && echo "done" || echo "failed"
fi

# Remove mount point
if [[ -d /mnt/lvm ]]; then
    echo -n "Removing mount point /mnt/lvm... "
    rmdir /mnt/lvm 2>/dev/null && echo "done" || echo "skipped"
fi

# Remove LV
if lvs /dev/datavg/vol0 2>/dev/null; then
    echo -n "Removing Logical Volume 'vol0'... "
    lvremove -f /dev/datavg/vol0 2>/dev/null && echo "done" || echo "failed"
fi

# Remove VG
if vgs datavg 2>/dev/null; then
    echo -n "Removing Volume Group 'datavg'... "
    vgremove -f datavg 2>/dev/null && echo "done" || echo "failed"
fi

# Remove PV (find and detach loopback)
if pvs 2>/dev/null | grep -q "loop"; then
    LOOP_DEV=$(pvs 2>/dev/null | grep "loop" | awk '{print $1}')
    if [[ -n "$LOOP_DEV" ]]; then
        echo -n "Removing Physical Volume ($LOOP_DEV)... "
        pvremove -ff "$LOOP_DEV" 2>/dev/null && echo "done" || echo "skipped"
    fi
fi

# Detach loopback device
if losetup /dev/loop0 2>/dev/null | grep -q "lvm.img"; then
    echo -n "Detaching loopback device /dev/loop0... "
    losetup -d /dev/loop0 2>/dev/null && echo "done" || echo "skipped"
fi

# Remove lvm.img
if [[ -f /tmp/lvm.img ]]; then
    echo -n "Removing /tmp/lvm.img... "
    rm -f /tmp/lvm.img && echo "done" || echo "failed"
fi

echo ""
echo "Cleanup completed."
