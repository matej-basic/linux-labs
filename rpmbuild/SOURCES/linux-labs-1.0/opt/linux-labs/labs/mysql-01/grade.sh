#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

passcount=0
failcount=0

pass() { echo -e "${GREEN}PASS${RESET}: $*"; ((passcount++)); }
fail() { echo -e "${RED}NO PASS${RESET}: $*"; ((failcount++)); rc=1; }

# Check if MySQL package is installed
if rpm -q mysql-server mariadb-server 2>/dev/null | grep -q mysql-server || rpm -q mariadb-server &>/dev/null; then
	pass "MySQL/MariaDB package installed"
else
	fail "MySQL/MariaDB package not installed"
fi

# Check if mysql service is running
if systemctl is-active --quiet mysqld || systemctl is-active --quiet mariadb || systemctl is-active --quiet mysqld; then
	pass "MySQL service is running"
else
	fail "MySQL service is not running"
fi

# Check if mysql is enabled on boot
if systemctl is-enabled --quiet mysqld || systemctl is-enabled --quiet mariadb || systemctl is-enabled --quiet mysqld; then
	pass "MySQL enabled on boot"
else
	fail "MySQL not enabled on boot"
fi

# Check if MySQL is listening on port 3306
if ss -tlnp 2>/dev/null | grep -q ':3306 '; then
	pass "MySQL listening on port 3306"
else
	fail "MySQL not listening on port 3306"
fi

# Check if root password is set to labpassword
if mysql -u root -plabpassword -e "SELECT 1" &>/dev/null; then
	pass "Root password set to labpassword"
else
	fail "Root password not set correctly"
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

