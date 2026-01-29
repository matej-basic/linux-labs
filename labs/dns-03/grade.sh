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

# Check if zone file exists
if [[ -f /var/named/labsecure.com.zone.signed ]]; then
	pass "Zone file exists"
else
	fail "Zone file does not exist"
fi

# Check if zone is signed
if [[ -f /var/named/labsecure.com.zone.signed ]]; then
	pass "Signed zone file exists"
else
	fail "Signed zone file does not exist"
fi

# Check if KSK exists
if ls /var/named/Klabsecure.com.+007+*.key >/dev/null 2>&1; then
	pass "KSK (Key Signing Key) found"
else
	fail "KSK not found"
fi

# Check if ZSK exists
if ls /var/named/Klabsecure.com.+007+*.key >/dev/null 2>&1 && [[ $(ls /var/named/Klabsecure.com.+007+*.key 2>/dev/null | wc -l) -ge 2 ]]; then
	pass "ZSK (Zone Signing Key) found"
else
	fail "ZSK not found"
fi

# Check if named service is running
if systemctl is-active --quiet named; then
	pass "named service is running"
else
	fail "named service is not running"
fi

# Check if DNSSEC validation is enabled
if grep -q "dnssec-validation auto" /etc/named.conf 2>/dev/null; then
	pass "DNSSEC validation enabled"
else
	fail "DNSSEC validation not enabled"
fi

# Check if zone transfer is configured
if grep -q "allow-transfer" /etc/named.conf 2>/dev/null; then
	pass "Zone transfer configured"
else
	fail "Zone transfer not configured"
fi

# Check DNSSEC signatures (verify zone file contains RRSIG records)
if grep -q "RRSIG" /var/named/labsecure.com.zone.signed; then
	pass "DNSSEC signatures verified (RRSIG records found)"
else
	fail "DNSSEC signatures not verified (no RRSIG records found)"
fi

# Check zone transfer works
if cd /tmp && dig @localhost labsecure.com axfr | grep -q "labsecure.com"; then
	pass "Zone transfer working"
else
	fail "Zone transfer not working"
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

