#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

passcount=0
failcount=0

pass() { echo -e "${GREEN}PASS${RESET}: $*"; ((passcount++)); }
fail() { echo -e "${RED}NO PASS${RESET}: $*"; ((failcount++)); rc=1; }

# Check if httpd package is installed
if rpm -q httpd &>/dev/null; then
	pass "httpd package installed"
else
	fail "httpd package not installed"
fi

# Check if httpd service is running
if systemctl is-active --quiet httpd; then
	pass "httpd service is running"
else
	fail "httpd service is not running"
fi

# Check if httpd is enabled on boot
if systemctl is-enabled --quiet httpd; then
	pass "httpd enabled on boot"
else
	fail "httpd not enabled on boot"
fi

# Check if Apache is listening on port 80
if ss -tlnp 2>/dev/null | grep -q ':80 '; then
	pass "Apache listening on port 80"
else
	fail "Apache not listening on port 80"
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

