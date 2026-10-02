#!/bin/bash
# mysql-02 setup: a running MySQL/MariaDB server with root password
# labpassword, and no labdb database or labuser user. Prints nothing on
# success.
#
# An existing server (servera keeps mysql-server from the replication
# labs) is used as it is. The first run records in /var/tmp/mysql-02.pre
# what the lab changes: whether the server was installed, the service
# state, the definition of root@localhost, a labdb database and labuser
# account that already existed, and which mysql history files existed.
# cleanup.sh puts all of it back. SQL run by this script and cleanup.sh
# is kept out of the binary log.
set -eu

ROOT_PW=labpassword
pre=/var/tmp/mysql-02.pre
servers="mysql-server mariadb-server"
lab_user=${LAB_USER:-student}
if ! getent passwd "$lab_user" >/dev/null; then
	lab_user=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 { print $1; exit }')
fi
lab_home=$(getent passwd "$lab_user" | cut -d: -f6)

die() {
	echo "mysql-02 setup: $*" >&2
	exit 1
}

# rootsql <sql>: run SQL as the database root user, labpassword first,
# then without a password (socket, or root's own option file)
rootsql() {
	MYSQL_PWD=$ROOT_PW mysql -u root -N -B -e "$1" </dev/null 2>/dev/null ||
		mysql -u root -N -B -e "$1" </dev/null 2>/dev/null
}

# First run only: record whether a server was there and how it was
if [ ! -d "$pre" ]; then
	rm -rf "$pre.tmp"
	mkdir -m 0700 "$pre.tmp"
	for p in $servers; do
		rpm -q "$p" >/dev/null 2>&1 && echo "$p-installed" >> "$pre.tmp/flags"
	done
	for u in mysqld mariadb; do
		systemctl is-enabled --quiet "$u" 2>/dev/null && echo "$u-enabled" >> "$pre.tmp/flags"
		systemctl is-active --quiet "$u" 2>/dev/null && echo "$u-active" >> "$pre.tmp/flags"
	done
	for h in "$lab_home" /root; do
		[ -n "$h" ] && [ -e "$h/.mysql_history" ] &&
			echo "history $h" >> "$pre.tmp/flags"
	done
	touch "$pre.tmp/flags"
	mv "$pre.tmp" "$pre"
fi

if rpm -q mariadb-server &>/dev/null; then
	svc=mariadb
else
	if ! rpm -q mysql-server &>/dev/null; then
		dnf -y install mysql-server </dev/null >/dev/null 2>&1 ||
			die "cannot install mysql-server"
	fi
	svc=mysqld
fi

systemctl enable --now "$svc" </dev/null >/dev/null 2>&1 ||
	die "cannot start $svc"

# Wait until the server answers (ping succeeds even if access is denied)
up=0
for _ in $(seq 1 60); do
	if mysqladmin --connect-timeout=2 ping </dev/null >/dev/null 2>&1; then
		up=1
		break
	fi
	sleep 1
done
[ "$up" = 1 ] || die "$svc does not answer"

rootsql 'SELECT 1' >/dev/null || die "cannot log in to $svc as root"

# First run with a server that was there before: save root@localhost,
# and labdb and labuser if they exist
if [ ! -f "$pre/saved" ] && grep -q -- '-installed$' "$pre/flags"; then
	# MySQL prints password hashes as hex, MariaDB has no such option
	rootsql "SET SESSION print_identified_with_as_hex=1; SHOW CREATE USER 'root'@'localhost'" > "$pre/root.sql" ||
		rootsql "SHOW CREATE USER 'root'@'localhost'" > "$pre/root.sql" ||
		die "cannot read the definition of root@localhost"
	if [ "$(rootsql "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name='labdb'")" = 1 ]; then
		MYSQL_PWD=$ROOT_PW mysqldump -u root --set-gtid-purged=OFF --databases labdb \
			> "$pre/labdb.sql" 2>/dev/null </dev/null ||
			mysqldump -u root --set-gtid-purged=OFF --databases labdb \
				> "$pre/labdb.sql" 2>/dev/null </dev/null ||
			mysqldump -u root --databases labdb > "$pre/labdb.sql" </dev/null ||
			die "cannot save the existing database labdb"
	fi
	if [ "$(rootsql "SELECT COUNT(*) FROM mysql.user WHERE User='labuser' AND Host='localhost'")" = 1 ]; then
		{
			rootsql "SET SESSION print_identified_with_as_hex=1; SHOW CREATE USER 'labuser'@'localhost'" ||
				rootsql "SHOW CREATE USER 'labuser'@'localhost'"
			rootsql "SHOW GRANTS FOR 'labuser'@'localhost'"
		} > "$pre/labuser.sql" || die "cannot save the existing user labuser"
	fi
	touch "$pre/saved"
fi

# Root password: set it when it is not labpassword yet
if ! MYSQL_PWD=$ROOT_PW mysql -u root -e 'SELECT 1' </dev/null >/dev/null 2>&1; then
	rootsql "SET sql_log_bin=0; ALTER USER 'root'@'localhost' IDENTIFIED BY '$ROOT_PW'" >/dev/null ||
		die "cannot set the database root password to $ROOT_PW"
fi

# Reset lab state
MYSQL_PWD=$ROOT_PW mysql -u root -e "SET sql_log_bin=0; DROP DATABASE IF EXISTS labdb; DROP USER IF EXISTS 'labuser'@'localhost'" \
	</dev/null >/dev/null 2>&1 || die "cannot reset labdb and labuser"
exit 0
