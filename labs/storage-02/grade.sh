#!/bin/bash

source /opt/linux-labs/lib/colors.sh

passcount=0
failcount=0

ok()   { pass "$*"; ((++passcount)); }
err()  { fail "$*"; ((++failcount)); }

# Check /tmp/lvm.img exists
if [[ -f /tmp/lvm.img ]]; then
    ok "/tmp/lvm.img exists"
else
    err "/tmp/lvm.img exists"
fi

# Check PV exists
if pvs 2>/dev/null | grep -q "loop"; then
    ok "Physical Volume exists"
else
    err "Physical Volume exists"
fi

# Check VG datavg exists
if vgs datavg 2>/dev/null | grep -q "datavg"; then
    ok "Volume Group 'datavg' exists"
else
    err "Volume Group 'datavg' exists"
fi

# Check LV vol0 exists
if lvs /dev/datavg/vol0 2>/dev/null | grep -q "vol0"; then
    ok "Logical Volume 'vol0' exists"
else
    err "Logical Volume 'vol0' exists"
fi

# Check LV size
SIZE=$(lvs /dev/datavg/vol0 2>/dev/null | tail -1 | awk '{print $4}')
if lvs /dev/datavg/vol0 2>/dev/null | tail -1 | awk '{print $4}' | grep -qE "80.0|8[0-9]|9[0-9]"; then
    ok "LV size at least 80MB (${SIZE})"
else
    err "LV size at least 80MB (got ${SIZE})"
fi

# Check /mnt/lvm exists
if [[ -d /mnt/lvm ]]; then
    ok "/mnt/lvm mount point exists"
else
    err "/mnt/lvm mount point exists"
fi

# Check /mnt/lvm mounted
if mountpoint -q /mnt/lvm; then
    ok "/mnt/lvm is mounted"
else
    err "/mnt/lvm is mounted"
fi

# Check filesystem type
FSTYPE=$(df -hPT /mnt/lvm 2>/dev/null | tail -1 | awk '{print $2}')
if [[ "$FSTYPE" == "ext4" ]]; then
    ok "filesystem type ext4"
else
    err "filesystem type ext4 (got ${FSTYPE})"
fi

# Check LV mounted correctly
if mount | grep -q "/dev/mapper/datavg-vol0.*on /mnt/lvm"; then
    ok "/dev/datavg/vol0 mounted at /mnt/lvm"
else
    err "/dev/datavg/vol0 mounted at /mnt/lvm"
fi

echo ""
echo "Results: $passcount passed, $failcount failed"

if [[ $failcount -eq 0 ]]; then
    pass "Lab completed successfully"
    exit 0
else
    fail "Lab incomplete"
    exit 1
fi
