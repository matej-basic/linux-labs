#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

passcount=0
failcount=0

pass() { echo -e "${GREEN}PASS${RESET}: $*"; ((++passcount)); }
fail() { echo -e "${RED}NO PASS${RESET}: $*"; ((++failcount)); rc=1; }

# Check if PostgreSQL is running
if systemctl is-active --quiet postgresql; then
	pass "PostgreSQL service is running"
else
	fail "PostgreSQL service is not running"
fi

# Check if backup file exists
if [ -f /tmp/labdb_backup.sql ]; then
	pass "Backup file /tmp/labdb_backup.sql exists"
else
	fail "Backup file /tmp/labdb_backup.sql not found"
fi

# Check if backup file is valid SQL
if grep -q "CREATE TABLE" /tmp/labdb_backup.sql; then
	pass "Backup file contains SQL statements"
else
	fail "Backup file does not contain valid SQL"
fi

# Check if labdb_restore database exists
if cd /tmp && sudo -u postgres psql -d labdb_restore -c "SELECT 1;" > /dev/null 2>&1; then
	pass "Database labdb_restore exists"
else
	fail "Database labdb_restore does not exist"
fi

# Check if users table exists in labdb_restore
if cd /tmp && sudo -u postgres psql -d labdb_restore -c "\dt users" 2>/dev/null | grep -q users; then
	pass "users table exists in labdb_restore"
else
	fail "users table does not exist in labdb_restore"
fi

# Check row count in original and restored database
original_count=$(cd /tmp && sudo -u postgres psql -t -d labdb -c "SELECT COUNT(*) FROM users;" 2>/dev/null | xargs)
restored_count=$(cd /tmp && sudo -u postgres psql -t -d labdb_restore -c "SELECT COUNT(*) FROM users;" 2>/dev/null | xargs)

if [ "$original_count" == "$restored_count" ] && [ -n "$original_count" ]; then
	pass "Data restored correctly ($original_count rows)"
else
	fail "Data row count mismatch (original: $original_count, restored: $restored_count)"
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

