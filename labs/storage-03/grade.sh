#!/bin/bash

source /opt/linux-labs/lib/colors.sh

passcount=0
failcount=0

ok()   { pass "$*"; ((++passcount)); }
err()  { fail "$*"; ((++failcount)); }

# Check /tmp/snap.img exists
if [[ -f /tmp/snap.img ]]; then
    ok "/tmp/snap.img exists"
else
    err "/tmp/snap.img exists"
fi

# Check PV exists
if pvs 2>/dev/null | grep -q "loop"; then
    ok "Physical Volume exists"
else
    err "Physical Volume exists"
fi

# Check VG snapvg exists
if vgs snapvg 2>/dev/null | grep -q "snapvg"; then
    ok "Volume Group 'snapvg' exists"
else
    err "Volume Group 'snapvg' exists"
fi

# Check LV original exists
if lvs /dev/snapvg/original 2>/dev/null | grep -q "original"; then
    ok "Logical Volume 'original' exists"
else
    err "Logical Volume 'original' exists"
fi

# Check original LV size
SIZE=$(lvs /dev/snapvg/original 2>/dev/null | tail -1 | awk '{print $4}')
if lvs /dev/snapvg/original 2>/dev/null | tail -1 | awk '{print $4}' | grep -q "100.0"; then
    ok "'original' LV size 100MB (${SIZE})"
else
    err "'original' LV size 100MB (got ${SIZE})"
fi

# Check snapshot snap1 exists
if lvs /dev/snapvg/snap1 2>/dev/null | grep -q "snap1"; then
    ok "Snapshot 'snap1' exists"
else
    err "Snapshot 'snap1' exists"
fi

# Check snapshot size
SIZE=$(lvs /dev/snapvg/snap1 2>/dev/null | tail -1 | awk '{print $4}')
if lvs /dev/snapvg/snap1 2>/dev/null | tail -1 | awk '{print $4}' | grep -q "20"; then
    ok "'snap1' snapshot size at least 20MB (${SIZE})"
else
    err "'snap1' snapshot size at least 20MB (got ${SIZE})"
fi

# Check /mnt/original mounted
if mountpoint -q /mnt/original; then
    ok "/mnt/original is mounted"
else
    err "/mnt/original is mounted"
fi

# Check /mnt/snap1 mounted
if mountpoint -q /mnt/snap1; then
    ok "/mnt/snap1 is mounted"
else
    err "/mnt/snap1 is mounted"
fi

# Check test data in /mnt/original
if [[ -f /mnt/original/testfile.txt ]]; then
    ok "test data in /mnt/original"
else
    err "test data in /mnt/original"
fi

# Check snapshot integrity
if [[ ! -f /mnt/snap1/testfile.txt ]]; then
    ok "snapshot doesn't contain new data"
else
    err "snapshot doesn't contain new data"
fi

# Check filesystem type
FSTYPE=$(df -hPT /mnt/original | tail -1 | awk '{print $2}')
if [[ "$FSTYPE" == "ext4" ]]; then
    ok "'original' filesystem type ext4"
else
    err "'original' filesystem type ext4 (got ${FSTYPE})"
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
