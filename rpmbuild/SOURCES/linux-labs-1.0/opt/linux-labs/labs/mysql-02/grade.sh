#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

passcount=0
failcount=0

pass() { echo -e "${GREEN}PASS${RESET}: $*"; ((passcount++)); }
fail() { echo -e "${RED}NO PASS${RESET}: $*"; ((failcount++)); rc=1; }

# Check if MySQL is running
if systemctl is-active --quiet mysqld || systemctl is-active --quiet mariadb; then
	pass "MySQL service is running"
else
	fail "MySQL service is not running"
fi

# Check if database labdb exists
if mysql -u root -plabpassword -e "USE labdb;" > /dev/null 2>&1; then
	pass "Database labdb exists"
else
	fail "Database labdb does not exist"
fi

# Check if user labuser exists
if mysql -u root -plabpassword -e "SELECT User FROM mysql.user WHERE User='labuser' AND Host='localhost';" > /dev/null 2>&1 | grep -q labuser; then
	pass "User labuser exists"
else
	fail "User labuser does not exist"
fi

# Check if user can connect with correct password
if mysql -u labuser -puserpass123 labdb -e "SELECT 1" > /dev/null 2>&1; then
	pass "User labuser can connect with correct password"
else
	fail "User labuser cannot connect or password is incorrect"
fi

# Check if users table exists in labdb
if mysql -u labuser -puserpass123 labdb -e "DESC users;" > /dev/null 2>&1; then
	pass "users table exists in labdb"
else
	fail "users table does not exist"
fi

# Check if table has at least 2 records
if mysql -u labuser -puserpass123 labdb -e "SELECT * FROM users;" > /dev/null 2>&1 | tail -n +2 | wc -l | grep -qE '^[2-9]|^[0-9]{2,}'; then
	pass "At least 2 sample records in users table"
else
	fail "Insufficient sample records in users table"
fi

# Check if user has SELECT privilege
if mysql -u root -plabpassword -e "SHOW GRANTS FOR 'labuser'@'localhost';" > /dev/null 2>&1 | grep -q "SELECT"; then
	pass "User has SELECT privilege"
else
	fail "User does not have SELECT privilege"
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

