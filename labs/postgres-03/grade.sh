#!/bin/bash
# postgres-03 grader
source /opt/linux-labs/lib/grading.sh

BACKUP=/tmp/labdb_backup.sql
STATE_FILE=/opt/linux-labs/state/postgres-03

# pg <database> <query>: unaligned, tuples only, as the postgres user
pg() {
	(cd /tmp && runuser -u postgres -- psql -X -At -d "$1" -c "$2" 2>/dev/null)
}

# Sorted rows of one table, as one checksum
table_sum() {
	pg "$1" "COPY (SELECT * FROM public.$2) TO STDOUT" | sort | md5sum | cut -d' ' -f1
}

grade_begin postgres-03
grade_require_state postgres-03 "$STATE_FILE"
orig_hash=$(sed -n 's/^hash=//p' "$STATE_FILE" | head -n 1)

backup_not_empty() {
	[ -s "$BACKUP" ]
}

backup_has_users_table() {
	grep -Eq '^CREATE TABLE (public\.)?users( |\()' "$BACKUP"
}

backup_has_all_rows() {
	local e n=0
	while IFS= read -r e; do
		[ -n "$e" ] || continue
		n=$((n + 1))
		grep -qF -- "$e" "$BACKUP" || return 1
	done < <(pg labdb 'SELECT email FROM public.users')
	[ "$n" -gt 0 ]
}

restore_db_exists() {
	[ "$(pg postgres "SELECT count(*) FROM pg_database WHERE datname = 'labdb_restore'")" = 1 ]
}

same_tables() {
	local a b
	a=$(pg labdb "SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY 1")
	b=$(pg labdb_restore "SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY 1")
	[ -n "$a" ] && [ "$a" = "$b" ]
}

same_users_rows() {
	local a b
	a=$(table_sum labdb users)
	b=$(table_sum labdb_restore users)
	[ "$(pg labdb_restore 'SELECT count(*) FROM public.users')" -gt 0 ] && [ "$a" = "$b" ]
}

same_all_rows() {
	local t
	for t in $(pg labdb "SELECT tablename FROM pg_tables WHERE schemaname = 'public'"); do
		[ "$(table_sum labdb "$t")" = "$(table_sum labdb_restore "$t")" ] || return 1
	done
}

labdb_unchanged() {
	[ -n "$orig_hash" ] && [ "$(table_sum labdb users)" = "$orig_hash" ]
}

criterion "PostgreSQL service is running" systemctl is-active --quiet postgresql
criterion "File $BACKUP exists and is not empty" backup_not_empty
criterion "Backup defines the table public.users" backup_has_users_table
criterion "Backup contains every row of the table users" backup_has_all_rows
criterion "Database labdb_restore exists" restore_db_exists
criterion "labdb_restore has the same tables as labdb" same_tables
criterion "Table users in labdb_restore has the same rows as in labdb" same_users_rows
criterion "Every table in labdb_restore has the same rows as in labdb" same_all_rows
criterion "Content of labdb is unchanged" labdb_unchanged
grade_end
