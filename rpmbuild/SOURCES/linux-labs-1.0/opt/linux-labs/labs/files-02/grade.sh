#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

passcount=0
failcount=0

pass() { echo -e "${GREEN}PASS${RESET}: $*"; ((passcount++)); }
fail() { echo -e "${RED}NO PASS${RESET}: $*"; ((failcount++)); }

# Check /tmp/webfiles structure
if [ -d /tmp/webfiles ] && [ -d /tmp/webfiles/app ] && [ -d /tmp/webfiles/config ] && [ -d /tmp/webfiles/data ]; then
    pass "directory structure created"
else
    fail "directory structure incomplete"
    rc=1
fi

# Check /tmp/webfiles
[ "$(stat -c '%U:%G %a' /tmp/webfiles 2>/dev/null)" = "root:root 755" ] && pass "/tmp/webfiles perms 755 root:root" || { fail "/tmp/webfiles perms/owner wrong"; rc=1; }

# Check /tmp/webfiles/app
[ "$(stat -c '%U:%G %a' /tmp/webfiles/app 2>/dev/null)" = "www-data:www-data 755" ] && pass "/tmp/webfiles/app perms 755 www-data:www-data" || { fail "/tmp/webfiles/app wrong"; rc=1; }

# Check /tmp/webfiles/config
[ "$(stat -c '%U:%G %a' /tmp/webfiles/config 2>/dev/null)" = "root:root 700" ] && pass "/tmp/webfiles/config perms 700 root:root" || { fail "/tmp/webfiles/config wrong"; rc=1; }

# Check /tmp/webfiles/data
[ "$(stat -c '%U:%G %a' /tmp/webfiles/data 2>/dev/null)" = "www-data:www-data 755" ] && pass "/tmp/webfiles/data perms 755 www-data:www-data" || { fail "/tmp/webfiles/data wrong"; rc=1; }

# Check files
[ -f /tmp/webfiles/app/index.php ] && [ "$(stat -c '%U:%G %a' /tmp/webfiles/app/index.php 2>/dev/null)" = "www-data:www-data 644" ] && pass "index.php correct" || { fail "index.php missing or wrong"; rc=1; }
[ -f /tmp/webfiles/app/upload.php ] && [ "$(stat -c '%U:%G %a' /tmp/webfiles/app/upload.php 2>/dev/null)" = "www-data:www-data 644" ] && pass "upload.php correct" || { fail "upload.php missing or wrong"; rc=1; }
[ -f /tmp/webfiles/config/db.conf ] && [ "$(stat -c '%U:%G %a' /tmp/webfiles/config/db.conf 2>/dev/null)" = "root:root 600" ] && pass "db.conf correct" || { fail "db.conf missing or wrong"; rc=1; }
[ -f /tmp/webfiles/data/app.log ] && [ "$(stat -c '%U:%G %a' /tmp/webfiles/data/app.log 2>/dev/null)" = "www-data:www-data 640" ] && pass "app.log correct" || { fail "app.log missing or wrong"; rc=1; }
[ -f /tmp/webfiles/data/error.log ] && [ "$(stat -c '%U:%G %a' /tmp/webfiles/data/error.log 2>/dev/null)" = "root:root 644" ] && pass "error.log correct" || { fail "error.log missing or wrong"; rc=1; }

echo ""
echo "Results: $passcount passed, $failcount failed"

if [[ $failcount -eq 0 ]]; then
    pass "Lab completed successfully"
    exit 0
else
    fail "Lab incomplete"
    exit 1
fi
