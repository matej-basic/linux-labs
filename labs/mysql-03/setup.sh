#!/bin/bash
# mysql-03 setup: make sure MySQL runs with the root password labpassword
# and a fresh database labdb (tables users and products). Removes any
# earlier backup and the restore database. Prints nothing on success.
set -eu

STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/mysql-03"
PASS=labpassword

# Remember whether this lab installed the server, so cleanup can undo it.
# A repeated run keeps the value from the first run.
installed=no
if [ -r "$STATE_FILE" ]; then
	installed=$(sed -n 's/^installed_by_lab=//p' "$STATE_FILE" | head -n 1)
fi

if ! rpm -q --quiet mysql-server && ! rpm -q --quiet mariadb-server; then
	dnf -q -y install mysql-server >/dev/null
	installed=yes
fi

svc=mysqld
if ! rpm -q --quiet mysql-server; then
	svc=mariadb
fi

mkdir -p "$STATE_DIR"
echo "installed_by_lab=${installed:-no}" > "$STATE_FILE"
chmod 644 "$STATE_FILE"

systemctl enable --now "$svc" >/dev/null 2>&1

# Wait until the server answers (socket login as the OS user root)
ready=
for _ in $(seq 1 60); do
	if mysqladmin --protocol=socket -u root ping >/dev/null 2>&1 ||
		MYSQL_PWD=$PASS mysqladmin -u root ping >/dev/null 2>&1; then
		ready=yes
		break
	fi
	sleep 1
done
if [ -z "$ready" ]; then
	echo "mysql-03 setup: $svc did not become ready" >&2
	exit 1
fi

# Root login: with the lab password if it is already set, else set it
if MYSQL_PWD=$PASS mysql -u root -e 'SELECT 1' >/dev/null 2>&1; then
	:
elif mysql --protocol=socket -u root -e 'SELECT 1' >/dev/null 2>&1; then
	mysql --protocol=socket -u root \
		-e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$PASS';"
else
	echo "mysql-03 setup: cannot log in to MySQL as root" >&2
	exit 1
fi

# Reset lab state
rm -f /tmp/labdb_backup.sql
MYSQL_PWD=$PASS mysql -u root <<'SQL'
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
