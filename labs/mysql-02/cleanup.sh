#!/bin/bash
# mysql-02 cleanup: drop labdb and labuser and put back what setup.sh
# recorded in /var/tmp/mysql-02.pre. A server that was there before the
# lab gets its root@localhost definition, any earlier labdb and labuser
# and its service state back. Then the package set of the first start
# comes back (pkg_restore), which removes a server the lab installed
# with its dependencies and the mysql user and group it created. The
# data and log files of such a server go before pkg_restore, since
# pkg_restore keeps a user that still owns files. When the package set
# cannot be restored, the records stay for the next reset and the exit
# status is 1.
source /opt/linux-labs/lib/packages.sh

ROOT_PW=labpassword
pre=/var/tmp/mysql-02.pre
servers="mysql-server mariadb-server"
datadir=/var/lib/mysql
lab_user=${LAB_USER:-student}
if ! getent passwd "$lab_user" >/dev/null; then
	lab_user=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 { print $1; exit }')
fi
lab_home=$(getent passwd "$lab_user" | cut -d: -f6)

# setup.sh did not get far enough to record anything but the packages
if [ ! -d "$pre" ]; then
	pkg_restore mysql-02 || exit 1
	exit 0
fi

had() {
	grep -qx "$1" "$pre/flags" 2>/dev/null
}

# rootsql: run SQL from stdin as the database root user, kept out of
# the binary log
rootsql() {
	local sql
	sql=$(cat)
	MYSQL_PWD=$ROOT_PW mysql -u root --init-command='SET sql_log_bin=0' \
		<<<"$sql" >/dev/null 2>&1 ||
		mysql -u root --init-command='SET sql_log_bin=0' \
			<<<"$sql" >/dev/null 2>&1
}

# MySQL prints an empty password as IDENTIFIED WITH '<plugin>' without
# AS, and replaying that expires the password: add the empty AS ''
no_expire="/IDENTIFIED WITH '[^']*' AS /!s/IDENTIFIED WITH '[^']*'/& AS ''/"

rc=0
preinstalled=no
for p in $servers; do
	had "$p-installed" && preinstalled=yes
done

if [ "$preinstalled" = yes ]; then
	if [ -f "$pre/saved" ]; then
		for u in mysqld mariadb; do
			rpm -q mysql-server mariadb-server >/dev/null 2>&1 || break
			systemctl start "$u" </dev/null >/dev/null 2>&1 && break
		done
		{
			echo "DROP DATABASE IF EXISTS labdb;"
			echo "DROP USER IF EXISTS 'labuser'@'localhost';"
		} | rootsql || {
			echo "Cannot drop labdb and labuser as the database root user" >&2
			rc=1
		}
		if [ -s "$pre/labdb.sql" ]; then
			rootsql < "$pre/labdb.sql" || {
				echo "Cannot restore the database labdb" >&2
				rc=1
			}
		fi
		if [ -s "$pre/labuser.sql" ]; then
			sed -e 's/$/;/' -e "$no_expire" "$pre/labuser.sql" | rootsql || {
				echo "Cannot restore the user labuser" >&2
				rc=1
			}
		fi
		# Root last, since it may take away the lab password
		if [ -s "$pre/root.sql" ]; then
			sed -e 's/^CREATE USER /ALTER USER /' -e 's/$/;/' -e "$no_expire" \
				"$pre/root.sql" |
				rootsql || {
				echo "Cannot restore the database root account" >&2
				rc=1
			}
		fi
	fi
else
	# The lab installed the server: remove its data and log files, so
	# that the mysql user owns no file when pkg_restore looks
	systemctl disable --now mysqld mariadb </dev/null >/dev/null 2>&1
	rm -rf "$datadir" /var/log/mysql /var/log/mariadb /var/lib/mysql-files \
		/var/lib/mysql-keyring
fi

pkg_restore mysql-02 || rc=1

if [ "$preinstalled" = yes ]; then
	for u in mysqld mariadb; do
		systemctl cat "$u" </dev/null >/dev/null 2>&1 || continue
		if had "$u-enabled"; then
			systemctl enable "$u" </dev/null >/dev/null 2>&1
		else
			systemctl disable "$u" </dev/null >/dev/null 2>&1
		fi
		if had "$u-active"; then
			systemctl start "$u" </dev/null >/dev/null 2>&1
		else
			systemctl stop "$u" </dev/null >/dev/null 2>&1
		fi
	done
else
	# Configuration files the package removal saved
	rm -f /etc/my.cnf.rpmsave /etc/my.cnf.d/*.rpmsave
fi

# mysql history files of the task user and root that the lab created
for h in "$lab_home" /root; do
	[ -n "$h" ] && ! had "history $h" && rm -f "$h/.mysql_history"
done

[ "$rc" -eq 0 ] && rm -rf "$pre"
exit "$rc"
