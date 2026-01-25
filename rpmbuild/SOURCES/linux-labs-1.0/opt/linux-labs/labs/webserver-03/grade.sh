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

# Check if mod_ssl is installed
if rpm -q mod_ssl &>/dev/null; then
	pass "mod_ssl installed"
else
	fail "mod_ssl not installed"
fi

# Check if directory exists
if [ -d /var/www/lab3/html ]; then
	pass "/var/www/lab3/html directory exists"
else
	fail "/var/www/lab3/html directory missing"
fi

# Check if index.html exists
if [ -f /var/www/lab3/html/index.html ]; then
	pass "index.html exists"
else
	fail "index.html missing"
fi

# Check if index.html contains required content
if grep -q "Lab 3 HTTPS" /var/www/lab3/html/index.html 2>/dev/null; then
	pass "index.html contains 'Lab 3 HTTPS'"
else
	fail "index.html missing required content"
fi

# Check if lab3.local is in /etc/hosts
if grep -q "lab3.local" /etc/hosts 2>/dev/null; then
	pass "lab3.local in /etc/hosts"
else
	fail "lab3.local not in /etc/hosts"
fi

# Check if SSL certificate exists
if [ -f /etc/pki/tls/certs/lab3.crt ]; then
	pass "SSL certificate exists"
else
	fail "SSL certificate missing"
fi

# Check if SSL private key exists
if [ -f /etc/pki/tls/private/lab3.key ]; then
	pass "SSL private key exists"
else
	fail "SSL private key missing"
fi

# Check if virtual host config exists
if [ -f /etc/httpd/conf.d/lab3.conf ]; then
	pass "Virtual host config exists"
else
	fail "Virtual host config missing"
fi

# Check if config contains HTTPS redirect
if grep -q "Redirect permanent" /etc/httpd/conf.d/lab3.conf 2>/dev/null; then
	pass "HTTP to HTTPS redirect configured"
else
	fail "HTTPS redirect not configured"
fi

# Check if Apache config is valid
if httpd -t 2>&1 | grep -q "Syntax OK"; then
	pass "Apache config is valid"
else
	fail "Apache config has errors"
fi

# Check if Apache is listening on port 443
if ss -tlnp 2>/dev/null | grep -q ':443 '; then
	pass "Apache listening on port 443"
else
	fail "Apache not listening on port 443"
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

