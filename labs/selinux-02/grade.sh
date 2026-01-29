#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

passcount=0
failcount=0

pass() { echo -e "${GREEN}PASS${RESET}: $*"; ((++passcount)); }
fail() { echo -e "${RED}NO PASS${RESET}: $*"; ((++failcount)); }

# Check if SELinux is available
if ! command -v getenforce >/dev/null 2>&1; then
    fail "SELinux not available"
    rc=1
fi

# Check /webapp structure
if [ -d /webapp/www ] && [ -d /webapp/config ] && [ -d /webapp/data ]; then
    pass "app directories created"
else
    fail "app directories missing"
    rc=1
fi

# Check files exist
if [ -f /webapp/www/index.html ] && [ -f /webapp/config/db.conf ] && [ -f /webapp/data/app.log ]; then
    pass "app files created"
else
    fail "app files missing"
    rc=1
fi

# Check Apache context applied to /tmp/myapp/www
if command -v getenforce >/dev/null 2>/dev/null; then
    if [ "$(getenforce 2>/dev/null)" != "Disabled" ]; then
        www_context=$(ls -Z /webapp/www/index.html 2>/dev/null | awk '{print $1}')
        if [[ "$www_context" == *"httpd_sys_rw_content_t"* ]]; then
            pass "/webapp/www has httpd context"
        else
            fail "/webapp/www context incorrect: $www_context"
            rc=1
        fi
    fi
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
