#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

passcount=0
failcount=0

pass() { echo -e "${GREEN}PASS${RESET}: $*"; ((++passcount)); }
fail() { echo -e "${RED}NO PASS${RESET}: $*"; ((++failcount)); rc=1; }

# Check if PostgreSQL package is installed
if rpm -q postgresql-server > /dev/null 2>&1; then
	pass "PostgreSQL package installed"
else
	fail "PostgreSQL package not installed"
fi

# Check if PostgreSQL service is running
if systemctl is-active --quiet postgresql; then
	pass "PostgreSQL service is running"
else
	fail "PostgreSQL service is not running"
fi

# Check if PostgreSQL is enabled on boot
if systemctl is-enabled --quiet postgresql; then
	pass "PostgreSQL enabled on boot"
else
	fail "PostgreSQL not enabled on boot"
fi

# Check if PostgreSQL is listening on port 5432
if ss -tlnp | grep -q ':5432 '; then
	pass "PostgreSQL listening on port 5432"
else
	fail "PostgreSQL not listening on port 5432"
fi

# Check if postgres user can connect to default database
if cd /tmp && sudo -u postgres psql -d postgres -c "SELECT version();" > /dev/null 2>&1; then
	pass "PostgreSQL CLI connection successful"
else
	fail "PostgreSQL CLI connection failed"
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

