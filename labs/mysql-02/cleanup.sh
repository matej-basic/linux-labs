#!/bin/bash
# mysql-02 cleanup: drop labdb and labuser. The server stays installed
# with root password labpassword, which mysql-03 expects.
SQL="DROP DATABASE IF EXISTS labdb; DROP USER IF EXISTS 'labuser'@'localhost'"

if ! mysql -u root -plabpassword -e "$SQL" >/dev/null 2>&1; then
	mysql -u root -e "$SQL" >/dev/null 2>&1 || true
fi
exit 0
