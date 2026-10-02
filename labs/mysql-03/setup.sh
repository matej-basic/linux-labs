#!/bin/bash
# mysql-03 setup: a running MySQL/MariaDB server with root password
# labpassword, a fresh database labdb (tables users and products), no
# database labdb_restore and no backup file. Prints nothing on success.
#
# An existing server (servera keeps mysql-server from the replication
# labs) is used as it is. The first run records in /var/tmp/mysql-03.pre
# what the lab changes: whether the server was installed, the service
# state, the definition of root@localhost, databases labdb and
# labdb_restore that already existed, and which mysql history files
# existed. cleanup.sh puts all of it back. SQL run by this script and
# cleanup.sh is kept out of the binary log.
set -eu

ROOT_PW=labpassword
BACKUP=/tmp/labdb_backup.sql
pre=/var/tmp/mysql-03.pre
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/mysql-03"
servers="mysql-server mariadb-server"
lab_user=${LAB_USER:-student}
if ! getent passwd "$lab_user" >/dev/null; then
	lab_user=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 { print $1; exit }')
fi
lab_home=$(getent passwd "$lab_user" | cut -d: -f6)

die() {
	echo "mysql-03 setup: $*" >&2
	exit 1
}

# rootsql <sql>: run SQL as the database root user, labpassword first,
# then without a password (socket, or root's own option file)
rootsql() {
	MYSQL_PWD=$ROOT_PW mysql -u root -N -B -e "$1" </dev/null 2>/dev/null ||
		mysql -u root -N -B -e "$1" </dev/null 2>/dev/null
}

# rootdump <db> <file>: dump one database with CREATE DATABASE
rootdump() {
	local opt
	for opt in --set-gtid-purged=OFF ""; do
		MYSQL_PWD=$ROOT_PW mysqldump -u root ${opt:+"$opt"} --databases "$1" \
			>"$2" 2>/dev/null </dev/null && return 0
		mysqldump -u root ${opt:+"$opt"} --databases "$1" \
			>"$2" 2>/dev/null </dev/null && return 0
	done
	return 1
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
# and labdb and labdb_restore if they exist
if [ ! -f "$pre/saved" ] && grep -q -- '-installed$' "$pre/flags"; then
	# MySQL prints password hashes as hex, MariaDB has no such option
	rootsql "SET SESSION print_identified_with_as_hex=1; SHOW CREATE USER 'root'@'localhost'" > "$pre/root.sql" ||
		rootsql "SHOW CREATE USER 'root'@'localhost'" > "$pre/root.sql" ||
		die "cannot read the definition of root@localhost"
	for db in labdb labdb_restore; do
		if [ "$(rootsql "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name='$db'")" = 1 ]; then
			rootdump "$db" "$pre/$db.sql" ||
				die "cannot save the existing database $db"
		fi
	done
	touch "$pre/saved"
fi

# Root password: set it when it is not labpassword yet
if ! MYSQL_PWD=$ROOT_PW mysql -u root -e 'SELECT 1' </dev/null >/dev/null 2>&1; then
	rootsql "SET sql_log_bin=0; ALTER USER 'root'@'localhost' IDENTIFIED BY '$ROOT_PW'" >/dev/null ||
		die "cannot set the database root password to $ROOT_PW"
fi

mkdir -p "$STATE_DIR"
echo "lab_user=$lab_user" > "$STATE_FILE"
chmod 644 "$STATE_FILE"

# Reset lab state
rm -f "$BACKUP"
MYSQL_PWD=$ROOT_PW mysql -u root --init-command='SET sql_log_bin=0' \
	>/dev/null 2>&1 <<'SQL' || die "cannot create the database labdb"
DROP DATABASE IF EXISTS labdb_restore;
DROP DATABASE IF EXISTS labdb;
CREATE DATABASE labdb;
USE labdb;
CREATE TABLE users (
  id INT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(50) NOT NULL,
  email VARCHAR(100) NOT NULL
);
INSERT INTO users (name, email) VALUES
  ('Alice Novak', 'alice@example.com'),
  ('Bob Horvat', 'bob@example.com'),
  ('Carla Kovac', 'carla@example.com'),
  ('Dino Babic', 'dino@example.com'),
  ('Eva Maric', 'eva@example.com');
CREATE TABLE products (
  id INT PRIMARY KEY,
  name VARCHAR(50) NOT NULL,
  price DECIMAL(8,2) NOT NULL
);
INSERT INTO products (id, name, price) VALUES
  (1, 'Keyboard', 29.90),
  (2, 'Monitor', 189.00),
  (3, 'Mouse', 12.50);
SQL
exit 0
