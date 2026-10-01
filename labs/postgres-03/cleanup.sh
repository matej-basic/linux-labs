#!/bin/bash
# postgres-03 cleanup: removes the restore database and the backup, and
# undoes what setup.sh created (labdb, table, rows, cluster, package).
STATE_FILE=/opt/linux-labs/state/postgres-03

flag() {
	[ -r "$STATE_FILE" ] && [ "$(sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1)" = 1 ]
}
pg() {
	(cd /tmp && runuser -u postgres -- psql -X -At -d "$1" -c "$2") > /dev/null 2>&1
}

rm -f /tmp/labdb_backup.sql

if rpm -q postgresql-server > /dev/null 2>&1; then
	# Start the server only to remove what the lab put into it
	if ! systemctl is-active --quiet postgresql; then
		systemctl start postgresql > /dev/null 2>&1
		for _ in 1 2 3 4 5 6 7 8 9 10; do
			pg postgres 'SELECT 1' && break
			sleep 1
		done
	fi
	pg postgres 'DROP DATABASE IF EXISTS labdb_restore'
	if flag db; then
		pg postgres 'DROP DATABASE IF EXISTS labdb'
	elif flag tbl; then
		pg labdb 'DROP TABLE IF EXISTS public.users'
	elif flag rows; then
		pg labdb 'DELETE FROM public.users'
	fi
fi

if flag pkg || flag init || flag svc; then
	systemctl stop postgresql > /dev/null 2>&1
fi
if flag init || flag pkg; then
	rm -rf /var/lib/pgsql/data
fi
if flag pkg; then
	dnf -y -q remove postgresql-server > /dev/null 2>&1
fi

rm -f "$STATE_FILE"
exit 0
