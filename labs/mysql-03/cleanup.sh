#!/bin/bash
# mysql-03 cleanup: drop labdb and labdb_restore, remove the backup file.
# If this lab installed the MySQL server, remove it with its data again.
STATE_FILE=/opt/linux-labs/state/mysql-03
PASS=labpassword

rm -f /tmp/labdb_backup.sql

# Drop the databases while the server is up (password or socket login)
if systemctl is-active --quiet mysqld || systemctl is-active --quiet mariadb; then
	for cred in "$PASS" ""; do
		if MYSQL_PWD=$cred mysql -u root -e 'SELECT 1' >/dev/null 2>&1; then
			MYSQL_PWD=$cred mysql -u root \
				-e 'DROP DATABASE IF EXISTS labdb_restore; DROP DATABASE IF EXISTS labdb;' \
				>/dev/null 2>&1 || true
			break
		fi
	done
fi

# Undo the installation only if setup did it
if [ -r "$STATE_FILE" ] && grep -qx 'installed_by_lab=yes' "$STATE_FILE"; then
	systemctl disable --now mysqld mariadb >/dev/null 2>&1 || true
	for pkg in mysql-server mariadb-server; do
		if rpm -q --quiet "$pkg"; then
			dnf -q -y remove "$pkg" >/dev/null 2>&1 || true
		fi
	done
	if [ -d /var/lib/mysql ]; then
		find /var/lib/mysql -mindepth 1 -delete 2>/dev/null || true
	fi
fi

rm -f "$STATE_FILE"
exit 0
