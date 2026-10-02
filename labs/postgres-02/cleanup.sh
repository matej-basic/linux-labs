#!/bin/bash
# postgres-02 cleanup: drop labdb and labuser and put back what setup.sh
# recorded in /var/tmp/postgres-02.pre. A server that was there before
# the lab gets its configuration files, roles and passwords, any earlier
# labdb and its service state back. A server the lab installed is
# removed with its packages, data, module stream and user postgres.

STATE_DIR=/opt/linux-labs/state/postgres-02
pre=/var/tmp/postgres-02.pre
home=/var/lib/pgsql
DATA=$home/data
modfile=/etc/dnf/modules.d/postgresql.module

pgsu() {
	(cd /tmp && runuser -u postgres -- psql -X -qAt "$@")
}

rm -rf "$STATE_DIR"

# setup.sh never ran: nothing to undo
[ -d "$pre" ] || exit 0

had() {
	grep -qx "$1" "$pre/flags" 2>/dev/null
}

rc=0

if had server; then
	# Database objects first, with the server running
	if [ -f "$pre/saved" ] && systemctl start postgresql </dev/null >/dev/null 2>&1; then
		for _ in $(seq 1 30); do
			pgsu -d postgres -c 'SELECT 1' >/dev/null 2>&1 && break
			sleep 1
		done
		pgsu -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'labdb'" >/dev/null 2>&1
		pgsu -d postgres -c "DROP DATABASE IF EXISTS labdb" >/dev/null 2>&1
		if [ "$(pgsu -d postgres -c "SELECT 1 FROM pg_roles WHERE rolname = 'labuser'" 2>/dev/null)" = 1 ]; then
			for db in $(pgsu -d postgres -c "SELECT datname FROM pg_database WHERE datallowconn" 2>/dev/null); do
				pgsu -d "$db" -c "DROP OWNED BY labuser" >/dev/null 2>&1
			done
			pgsu -d postgres -c "DROP ROLE labuser" >/dev/null 2>&1 || {
				echo "Cannot drop the role labuser" >&2
				rc=1
			}
		fi
		# Roles, attributes and passwords as they were; CREATE ROLE
		# fails for roles that exist, which is expected
		pgsu -d postgres < "$pre/roles.sql" >/dev/null 2>&1
		if [ -s "$pre/labdb.sql" ]; then
			pgsu -d postgres -v ON_ERROR_STOP=1 < "$pre/labdb.sql" >/dev/null 2>&1 || {
				echo "Cannot restore the database labdb" >&2
				rc=1
			}
		fi
	fi
	# Configuration files as they were
	for f in "$pre"/conf/*; do
		[ -f "$f" ] || continue
		cat "$f" > "$DATA/$(basename "$f")"
	done
	systemctl stop postgresql </dev/null >/dev/null 2>&1
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
	# A data directory that setup.sh initialised
	had data || rm -rf "$DATA"
else
	# The lab installed the server: remove it, every postgresql* or
	# libpq package that came with it, and the files it left behind
	systemctl disable --now postgresql </dev/null >/dev/null 2>&1
	remove=""
	for nevra in $(rpm -qa 'postgresql*' 'libpq*'); do
		grep -qx "$nevra" "$pre/rpms" && continue
		remove="$remove $(rpm -q --qf '%{NAME}' "$nevra")"
	done
	if [ -n "$remove" ]; then
		# shellcheck disable=SC2086 # word splitting is intended
		dnf -y remove $remove </dev/null >/dev/null 2>&1 || {
			echo "Cannot remove$remove" >&2
			rc=1
		}
	fi
	if [ -f "$pre/postgresql.module" ]; then
		cp -p "$pre/postgresql.module" "$modfile"
	else
		rm -f "$modfile"
	fi
	had home || rm -rf "$home"
	if ! had user && getent passwd postgres >/dev/null; then
		userdel postgres >/dev/null 2>&1
		getent group postgres >/dev/null && groupdel postgres >/dev/null 2>&1
	fi
fi

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

rm -rf "$pre"
exit "$rc"
