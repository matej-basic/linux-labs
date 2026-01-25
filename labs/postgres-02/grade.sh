#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

passcount=0
failcount=0

pass() { echo -e "${GREEN}PASS${RESET}: $*"; ((passcount++)); }
fail() { echo -e "${RED}NO PASS${RESET}: $*"; ((failcount++)); rc=1; }

# Check if PostgreSQL is running
if systemctl is-active --quiet postgresql; then
	pass "PostgreSQL service is running"
else
	fail "PostgreSQL service is not running"
fi

# Check if database labdb exists
if cd /tmp && sudo -u postgres psql -d labdb -c "SELECT 1;" > /dev/null 2>&1; then
	pass "Database labdb exists"
else
	fail "Database labdb does not exist"
fi

# Check if role labuser exists
if cd /tmp && sudo -u postgres psql -d postgres -c "SELECT usename FROM pg_user WHERE usename='labuser';" | grep -q labuser; then
	pass "Role labuser exists"
else
	fail "Role labuser does not exist"
fi

# Check if user can connect with correct password
if cd /tmp && PGPASSWORD=userpass123 psql -U labuser -d labdb -h localhost -c "SELECT 1;" > /dev/null 2>&1; then
	pass "User labuser can connect with correct password"
else
	fail "User labuser cannot connect or password is incorrect"
fi

# Check if users table exists
if cd /tmp && sudo -u postgres psql -d labdb -c "\dt users" | grep -q users; then
	pass "users table exists in labdb"
else
	fail "users table does not exist"
fi

# Check if table has at least 2 records
record_count=$(cd /tmp && PGPASSWORD=userpass123 psql -U labuser -d labdb -h localhost -t -c "SELECT COUNT(*) FROM users;" | xargs)
if [ "$record_count" -ge 2 ] > /dev/null 2>&1; then
	pass "At least 2 sample records in users table"
else
	fail "Insufficient sample records in users table"
fi

# Check if user has SELECT privilege on users table
if sudo -u postgres psql -d labdb -c "\dp users" 2>/dev/null | grep -q labuser; then
	pass "User has privileges on users table"
else
	fail "User does not have privileges on users table"
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

