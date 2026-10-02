#!/bin/bash
# mysql-03 grader
source /opt/linux-labs/lib/grading.sh

BACKUP=/tmp/labdb_backup.sql
STATE_FILE=/opt/linux-labs/state/mysql-03
TABLES=(users products)

# Run a query as MySQL root (the lab password is part of the task)
sql() {
	local db=$1 query=$2
	MYSQL_PWD=labpassword mysql --no-defaults -u root -N -B "$db" -e "$query"
}

mysql_running() {
	systemctl is-active --quiet mysqld || systemctl is-active --quiet mariadb
}

labdb_unchanged() {
	[ "$(sql labdb 'SELECT COUNT(*) FROM users')" = 5 ] &&
		[ "$(sql labdb 'SELECT COUNT(*) FROM products')" = 3 ] &&
		[ "$(sql labdb "SELECT GROUP_CONCAT(name ORDER BY id) FROM users")" = \
			"Alice Novak,Bob Horvat,Carla Kovac,Dino Babic,Eva Maric" ]
}

backup_has_tables() {
	local t
	[ -s "$BACKUP" ] || return 1
	for t in "${TABLES[@]}"; do
		grep -q "^CREATE TABLE \`$t\`" "$BACKUP" || return 1
		grep -q "^INSERT INTO \`$t\`" "$BACKUP" || return 1
	done
}

restore_db_exists() {
	[ "$(sql information_schema "SELECT COUNT(*) FROM schemata WHERE schema_name='labdb_restore'")" = 1 ]
}

same_tables() {
	local a b
	a=$(sql information_schema "SELECT table_name FROM tables WHERE table_schema='labdb' ORDER BY 1") || return 1
	b=$(sql information_schema "SELECT table_name FROM tables WHERE table_schema='labdb_restore' ORDER BY 1") || return 1
	[ -n "$a" ] && [ "$a" = "$b" ] && [ "$a" = "$(printf '%s\n' "${TABLES[@]}" | sort)" ]
}

same_rows() {
	local t a b
	for t in "${TABLES[@]}"; do
		a=$(sql labdb "SELECT * FROM $t ORDER BY id") || return 1
		b=$(sql labdb_restore "SELECT * FROM $t ORDER BY id") || return 1
		[ -n "$a" ] && [ "$a" = "$b" ] || return 1
	done
}

grade_begin mysql-03
grade_require_state mysql-03 "$STATE_FILE"

criterion "MySQL server is running" mysql_running
criterion "Database labdb is unchanged (users 5 rows, products 3 rows)" labdb_unchanged
criterion "Backup file $BACKUP exists and is not empty" test -s "$BACKUP"
criterion "Backup file contains tables and rows of labdb" backup_has_tables
criterion "Database labdb_restore exists" restore_db_exists
criterion "labdb_restore has the same tables as labdb" same_tables
criterion "labdb_restore has the same rows as labdb" same_rows
grade_end
