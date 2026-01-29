#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

passcount=0
failcount=0

pass() { echo -e "${GREEN}PASS${RESET}: $*"; ((++passcount)); }
fail() { echo -e "${RED}NO PASS${RESET}: $*"; ((++failcount)); rc=1; }

# Check if bind package is installed
if rpm -q bind > /dev/null 2>&1; then
	pass "bind package installed"
else
	fail "bind package not installed"
fi

# Check if bind-utils package is installed
if rpm -q bind-utils > /dev/null 2>&1; then
	pass "bind-utils package installed"
else
	fail "bind-utils package not installed"
fi

# Check if named service is running
if systemctl is-active --quiet named; then
	pass "named service is running"
else
	fail "named service is not running"
fi

# Check if named is enabled on boot
if systemctl is-enabled --quiet named; then
	pass "named enabled on boot"
else
	fail "named not enabled on boot"
fi

# Check if BIND is listening on port 53 UDP
if ss -ulnp 2>/dev/null | grep -q ':53 '; then
	pass "BIND listening on port 53 (UDP)"
else
	fail "BIND not listening on port 53 (UDP)"
fi

# Check if BIND is listening on port 53 TCP
if ss -tlnp 2>/dev/null | grep -q ':53 '; then
	pass "BIND listening on port 53 (TCP)"
else
	fail "BIND not listening on port 53 (TCP)"
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

