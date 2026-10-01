#!/bin/bash
# mysql-02 grader
source /opt/linux-labs/lib/grading.sh

# Run SQL as the database root user and print rows without headers
rootsql() {
	mysql -u root -plabpassword -N -B -e "$1" 2>/dev/null
}

server_running() {
	systemctl is-active --quiet mysqld || systemctl is-active --quiet mariadb
}

database_exists() {
	[ "$(rootsql "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name='labdb'")" = 1 ]
}

user_exists() {
	[ "$(rootsql "SELECT COUNT(*) FROM mysql.user WHERE User='labuser' AND Host='localhost'")" = 1 ]
}

user_can_login() {
	mysql -u labuser -puserpass123 labdb -e 'SELECT 1' &>/dev/null
}

table_has_columns() {
	[ "$(rootsql "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='labdb' AND table_name='users' AND column_name IN ('id','name','email')")" = 3 ]
}

table_has_rows() {
	local n
	n=$(rootsql "SELECT COUNT(*) FROM labdb.users") || return 1
	[ "$n" -ge 2 ] 2>/dev/null
}

user_can_read_table() {
	mysql -u labuser -puserpass123 labdb -e 'SELECT * FROM users' &>/dev/null
}

# All grants of labuser@localhost, backticks removed
grants() {
	rootsql "SHOW GRANTS FOR 'labuser'@'localhost'" | tr -d '`'
}

# Privileges granted on labdb.*, one per line, sorted
labdb_privs() {
	grants | sed -n 's/^GRANT \(.*\) ON labdb\.\* TO .*/\1/p' |
		tr ',' '\n' | tr -d ' ' | sort -u
}

has_four_privileges() {
	local p privs
	privs=$(labdb_privs)
	for p in SELECT INSERT UPDATE DELETE; do
		printf '%s\n' "$privs" | grep -qx "$p" || return 1
	done
}

# Nothing beyond the four privileges on labdb, nothing on other objects
only_those_privileges() {
	local g line obj
	g=$(grants) || return 1
	[ -n "$g" ] || return 1
	[ "$(labdb_privs | paste -sd, -)" = "DELETE,INSERT,SELECT,UPDATE" ] || return 1
	case "$g" in *"WITH GRANT OPTION"*) return 1 ;; esac
	while IFS= read -r line; do
		obj=$(printf '%s\n' "$line" | sed -n 's/^GRANT .* ON \(.*\) TO .*/\1/p')
		case "$obj" in
		labdb.*) ;;
		'*.*') [ "${line#GRANT USAGE ON }" != "$line" ] || return 1 ;;
		*) return 1 ;;
		esac
	done <<<"$g"
}

grade_begin mysql-02
criterion "The database server is running" server_running
criterion "Database labdb exists" database_exists
criterion "User labuser@localhost exists" user_exists
criterion "labuser can log in to labdb with password userpass123" user_can_login
criterion "Table labdb.users has the columns id, name and email" table_has_columns
criterion "Table labdb.users holds at least 2 rows" table_has_rows
criterion "labuser can read the table users" user_can_read_table
criterion "labuser has SELECT, INSERT, UPDATE, DELETE on labdb.*" has_four_privileges
criterion "labuser has no other privileges and no grant option" only_those_privileges
grade_end
