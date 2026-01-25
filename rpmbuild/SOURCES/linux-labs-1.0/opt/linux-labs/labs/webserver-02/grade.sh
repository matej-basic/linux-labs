#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

passcount=0
failcount=0

pass() { echo -e "${GREEN}PASS${RESET}: $*"; ((passcount++)); }
fail() { echo -e "${RED}NO PASS${RESET}: $*"; ((failcount++)); rc=1; }

# Check if httpd package is installed and running
if rpm -q httpd &>/dev/null; then
	pass "httpd package installed"
else
	fail "httpd package not installed"
fi

if systemctl is-active --quiet httpd; then
	pass "httpd service is running"
else
	fail "httpd service is not running"
fi

# Check if directory exists
if [ -d /var/www/lab2/html ]; then
	pass "/var/www/lab2/html directory exists"
else
	fail "/var/www/lab2/html directory missing"
fi

# Check if index.html exists
if [ -f /var/www/lab2/html/index.html ]; then
	pass "index.html exists"
else
	fail "index.html missing"
fi

# Check if index.html contains required content
if grep -q "Welcome to Lab 2" /var/www/lab2/html/index.html 2>/dev/null; then
	pass "index.html contains 'Welcome to Lab 2'"
else
	fail "index.html missing required content"
fi

# Check if lab2.local is in /etc/hosts
if grep -q "lab2.local" /etc/hosts 2>/dev/null; then
	pass "lab2.local in /etc/hosts"
else
	fail "lab2.local not in /etc/hosts"
fi

# Check if virtual host config exists
if [ -f /etc/httpd/conf.d/lab2.conf ]; then
	pass "Virtual host config exists"
else
	fail "Virtual host config missing"
fi

# Check if config is valid
if httpd -t 2>&1 | grep -q "Syntax OK"; then
	pass "Apache config is valid"
else
	fail "Apache config has errors"
fi

# Check if curl can reach lab2.local
if curl -s http://lab2.local 2>/dev/null | grep -q "Welcome to Lab 2"; then
	pass "lab2.local is accessible"
else
	fail "lab2.local not accessible"
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

