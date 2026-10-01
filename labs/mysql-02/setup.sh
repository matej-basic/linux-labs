#!/bin/bash
# mysql-02 setup: a running MySQL/MariaDB server with root password
# labpassword, and no labdb database or labuser user. Prints nothing on
# success.
set -eu

ROOT_PW=labpassword

die() {
	echo "mysql-02 setup: $*" >&2
	exit 1
}

# Server package and service: use an installed MariaDB, else MySQL
# (mysql-server exists in AppStream on Rocky 8 and 9).
if rpm -q mariadb-server &>/dev/null; then
	svc=mariadb
else
	if ! rpm -q mysql-server &>/dev/null; then
		dnf -y install mysql-server >/dev/null 2>&1 ||
			die "cannot install mysql-server"
	fi
	svc=mysqld
fi

systemctl enable --now "$svc" >/dev/null 2>&1 ||
	die "cannot start $svc"

# Wait until the server answers (ping succeeds even if access is denied)
up=0
for _ in $(seq 1 60); do
	if mysqladmin --connect-timeout=2 ping >/dev/null 2>&1; then
		up=1
		break
	fi
	sleep 1
done
[ "$up" = 1 ] || die "$svc does not answer"

# Root password: set it through the socket when it is not labpassword yet
if ! mysql -u root "-p$ROOT_PW" -e 'SELECT 1' >/dev/null 2>&1; then
	mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$ROOT_PW'" \
		>/dev/null 2>&1 ||
		die "cannot set the database root password to $ROOT_PW"
fi

# Reset lab state
mysql -u root "-p$ROOT_PW" -e "DROP DATABASE IF EXISTS labdb; DROP USER IF EXISTS 'labuser'@'localhost'" \
	>/dev/null 2>&1 || die "cannot reset labdb and labuser"
exit 0
