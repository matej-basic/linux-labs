#!/bin/bash

source /opt/linux-labs/lib/colors.sh

failcount=0
passcount=0

# Helpers
ok()   { pass "$*"; ((++passcount)); }
err()  { fail "$*"; ((++failcount)); }

# Check /tmp/disk.img exists
if [[ -f /tmp/disk.img ]]; then
    ok "/tmp/disk.img exists"
else
    err "/tmp/disk.img exists"
fi

# Check /mnt/data exists
if [[ -d /mnt/data ]]; then
    ok "/mnt/data mount point exists"
else
    err "/mnt/data mount point exists"
fi

# Check if mounted
if mountpoint -q /mnt/data; then
    ok "/mnt/data is mounted"
else
    err "/mnt/data is mounted"
fi

# Check permissions
PERMS=$(stat -c %a /mnt/data 2>/dev/null || echo "")
if [[ "$PERMS" == "755" ]]; then
    ok "/mnt/data perms 755"
else
    err "/mnt/data perms 755 (got ${PERMS:-unknown})"
fi

# Check filesystem type
FSTYPE=$(findmnt -n -o FSTYPE /mnt/data 2>/dev/null || echo "")
if [[ "$FSTYPE" == "ext4" ]]; then
    ok "filesystem type ext4"
else
    err "filesystem type ext4 (got ${FSTYPE:-unknown})"
fi

# Check fstab entry
if grep -qE '(/tmp/disk.img|UUID=.*[[:space:]]+/mnt/data[[:space:]]+ext4)' /etc/fstab; then
    ok "fstab entry for /mnt/data"
else
    err "fstab entry for /mnt/data"
fi

# Check size
SIZE_MB=$(du -m /tmp/disk.img 2>/dev/null | awk '{print $1}')
if [[ ${SIZE_MB:-0} -ge 95 && ${SIZE_MB:-0} -le 105 ]]; then
    ok "image size ~100MB (${SIZE_MB}MB)"
else
    err "image size ~100MB (got ${SIZE_MB:-unknown}MB)"
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
