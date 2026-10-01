#!/bin/bash
# postgres-02 grader
source /opt/linux-labs/lib/grading.sh

STATE_FILE=/opt/linux-labs/state/postgres-02/state
PASSWORD=userpass123

# Query as the postgres superuser over the local socket
q() {
	(cd /tmp && runuser -u postgres -- psql -X -qAt -d "$1" -c "$2" 2>/dev/null)
}

# Query as labuser over TCP with the given password
qu() {
	PGPASSWORD="$1" PGPASSFILE=/dev/null PGCONNECT_TIMEOUT=5 \
		psql -X -qAt -h 127.0.0.1 -U labuser -d labdb -c "$2" 2>/dev/null
}

role_can_login() {
	[ "$(q postgres "SELECT 1 FROM pg_roles WHERE rolname = 'labuser' AND rolcanlogin")" = 1 ]
}

role_not_admin() {
	[ "$(q postgres "SELECT 1 FROM pg_roles WHERE rolname = 'labuser' AND NOT rolsuper AND NOT rolcreatedb AND NOT rolcreaterole AND NOT rolreplication AND NOT rolbypassrls")" = 1 ]
}

db_exists() {
	[ "$(q postgres "SELECT 1 FROM pg_database WHERE datname = 'labdb'")" = 1 ]
}

login_ok() {
	[ "$(qu "$PASSWORD" "SELECT 1")" = 1 ]
}

# A wrong password is rejected (only meaningful when the right one works)
wrong_password_rejected() {
	login_ok || return 1
	[ "$(qu "wrongpass-$$" "SELECT 1")" != 1 ]
}

can_connect_labdb() {
	[ "$(q postgres "SELECT has_database_privilege('labuser', 'labdb', 'CONNECT')")" = t ]
}

can_use_schema() {
	[ "$(q labdb "SELECT has_schema_privilege('labuser', 'public', 'USAGE')")" = t ]
}

table_has_columns() {
	[ "$(q labdb "SELECT count(DISTINCT column_name) FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'users' AND column_name IN ('id', 'name', 'email')")" = 3 ]
}

table_privileges() {
	[ "$(q labdb "SELECT bool_and(has_table_privilege('labuser', 'public.users', p)) FROM unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE']) AS p")" = t ]
}

table_has_rows() {
	local n
	n=$(q labdb "SELECT count(*) FROM public.users")
	[[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 2 ]
}

grade_begin postgres-02
grade_require_state postgres-02 "$STATE_FILE"

criterion "PostgreSQL service is running" systemctl is-active --quiet postgresql
criterion "labuser logs in over TCP with the password $PASSWORD" login_ok
criterion "A wrong password for labuser is rejected over TCP" wrong_password_rejected
criterion "Role labuser exists and can log in" role_can_login
criterion "Role labuser has no administrative privileges" role_not_admin
criterion "Database labdb exists" db_exists
criterion "labuser may connect to labdb" can_connect_labdb
criterion "labuser may use the public schema in labdb" can_use_schema
criterion "Table users in labdb has the columns id, name and email" table_has_columns
criterion "labuser has SELECT, INSERT, UPDATE and DELETE on users" table_privileges
criterion "Table users contains at least 2 rows" table_has_rows
grade_end
