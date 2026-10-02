#!/bin/bash
# postgres-03 cleanup: drop labdb and labdb_restore, remove the backup
# file and put back what setup.sh recorded in /var/tmp/postgres-03.pre.
# A server that was there before the lab gets its configuration files,
# roles and passwords, any earlier labdb or labdb_restore and its
# service state back. Then the package set of the first start comes
# back (pkg_restore), which removes a server the lab installed with its
# dependencies, module stream and the user postgres. The data of such a
# server goes before pkg_restore, since pkg_restore keeps a user that
# still owns files. When the package set cannot be restored, the
# records stay for the next reset and the exit status is 1.
source /opt/linux-labs/lib/packages.sh

STATE_FILE=/opt/linux-labs/state/postgres-03
BACKUP=/tmp/labdb_backup.sql
pre=/var/tmp/postgres-03.pre
home=/var/lib/pgsql
DATA=$home/data
LAB_DBS="labdb labdb_restore"

pgsu() {
	(cd /tmp && PGOPTIONS='-c client_min_messages=warning' runuser -u postgres -- psql -X -qAt "$@")
}

rm -f "$STATE_FILE" "$BACKUP"

# setup.sh did not get far enough to record anything but the packages
if [ ! -d "$pre" ]; then
	pkg_restore postgres-03 || exit 1
	exit 0
fi

had() {
	grep -qx "$1" "$pre/flags" 2>/dev/null
}

rc=0
preinstalled=no
pkg_was_installed postgres-03 postgresql-server && preinstalled=yes

# Firewall service postgresql as it was
if had firewalld && firewall-cmd --state >/dev/null 2>&1; then
	if had fw-runtime; then
		firewall-cmd --add-service=postgresql >/dev/null 2>&1
	else
		firewall-cmd --remove-service=postgresql >/dev/null 2>&1
	fi
	if had fw-permanent; then
		firewall-cmd --permanent --add-service=postgresql >/dev/null 2>&1
	else
		firewall-cmd --permanent --remove-service=postgresql >/dev/null 2>&1
	fi
fi

# psql history and .pgpass files: the saved ones back, new ones gone
lab_user=${LAB_USER:-student}
if ! getent passwd "$lab_user" >/dev/null; then
	lab_user=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 { print $1; exit }')
fi
lab_home=$(getent passwd "$lab_user" | cut -d: -f6)
for h in "$lab_home" /root "$home"; do
	[ -n "$h" ] && [ -d "$h" ] || continue
	for f in .psql_history .pgpass; do
		p="$h/$f"
		if grep -qx "$p" "$pre/files.list" 2>/dev/null; then
			saved="$pre/files/$(echo "$p" | tr / %)"
			if [ -f "$p" ]; then
				cat "$saved" > "$p"
			else
				cp -p "$saved" "$p"
				restorecon "$p" >/dev/null 2>&1
			fi
		else
			rm -f "$p"
		fi
	done
done

if [ "$preinstalled" = yes ]; then
	# Database objects first, with the server running
	if [ -f "$pre/saved" ] && systemctl start postgresql </dev/null >/dev/null 2>&1; then
		for _ in $(seq 1 30); do
			pgsu -d postgres -c 'SELECT 1' >/dev/null 2>&1 && break
			sleep 1
		done
		for db in $LAB_DBS; do
			pgsu -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$db'" >/dev/null 2>&1
			pgsu -d postgres -c "DROP DATABASE IF EXISTS $db" >/dev/null 2>&1 || {
				echo "Cannot drop the database $db" >&2
				rc=1
			}
		done
		# Roles, attributes and passwords as they were; CREATE ROLE
		# fails for roles that exist, which is expected
		pgsu -d postgres < "$pre/roles.sql" >/dev/null 2>&1
		for db in $LAB_DBS; do
			[ -s "$pre/$db.sql" ] || continue
			pgsu -d postgres -v ON_ERROR_STOP=1 < "$pre/$db.sql" >/dev/null 2>&1 || {
				echo "Cannot restore the database $db" >&2
				rc=1
			}
		done
	fi
	# Configuration files as they were
	for f in "$pre"/conf/*; do
		[ -f "$f" ] && [ -d "$DATA" ] || continue
		cat "$f" > "$DATA/$(basename "$f")"
	done
	systemctl stop postgresql </dev/null >/dev/null 2>&1
	# A data directory that setup.sh initialised
	had data || rm -rf "$DATA"
else
	# The lab installed the server: remove its data, so that the user
	# postgres owns no file when pkg_restore looks. A /var/lib/pgsql
	# that was there before the lab stays, without a cluster that
	# setup.sh initialised.
	systemctl disable --now postgresql </dev/null >/dev/null 2>&1
	if had home; then
		had data || rm -rf "$DATA"
	else
		rm -rf "$home"
	fi
fi

pkg_restore postgres-03 || rc=1

if [ "$preinstalled" = yes ]; then
	if had enabled; then
		systemctl enable postgresql </dev/null >/dev/null 2>&1
	else
		systemctl disable postgresql </dev/null >/dev/null 2>&1
	fi
	if had active; then
		systemctl start postgresql </dev/null >/dev/null 2>&1 || {
			echo "Cannot start postgresql" >&2
			rc=1
		}
	fi
fi

[ "$rc" -eq 0 ] && rm -rf "$pre"
exit "$rc"
