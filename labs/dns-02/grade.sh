#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

passcount=0
failcount=0

pass() { echo -e "${GREEN}PASS${RESET}: $*"; ((passcount++)); }
fail() { echo -e "${RED}NO PASS${RESET}: $*"; ((failcount++)); rc=1; }

# Check if bind package is installed
if rpm -q bind > /dev/null 2>&1; then
	pass "bind package installed"
else
	fail "bind package not installed"
fi

# Check if zone file exists
if [[ -f /var/named/labdomain.com.zone ]]; then
	pass "Zone file exists"
else
	fail "Zone file does not exist"
fi

# Check if zone file contains SOA record
if grep -q "^@.*IN.*SOA" /var/named/labdomain.com.zone 2>/dev/null; then
	pass "SOA record found in zone file"
else
	fail "SOA record not found in zone file"
fi

# Check if named service is running
if systemctl is-active --quiet named; then
	pass "named service is running"
else
	fail "named service is not running"
fi

# Check if web A record exists
if cd /tmp && dig @localhost web.labdomain.com A +short 2>/dev/null | grep -q "192.168.1.10"; then
	pass "A record for web.labdomain.com resolves correctly"
else
	fail "A record for web.labdomain.com not found or incorrect"
fi

# Check if mail A record exists
if cd /tmp && dig @localhost mail.labdomain.com A +short 2>/dev/null | grep -q "192.168.1.20"; then
	pass "A record for mail.labdomain.com resolves correctly"
else
	fail "A record for mail.labdomain.com not found or incorrect"
fi

# Check if CNAME record exists
if cd /tmp && dig @localhost www.labdomain.com +short 2>/dev/null | grep -q "web.labdomain.com"; then
	pass "CNAME record for www resolves correctly"
else
	fail "CNAME record for www not found or incorrect"
fi

# Check if MX record exists
if cd /tmp && dig @localhost labdomain.com MX +short 2>/dev/null | grep -q "mail.labdomain.com"; then
	pass "MX record found"
else
	fail "MX record not found"
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

