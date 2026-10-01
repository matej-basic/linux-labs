#!/bin/bash
# mysql-01 setup: remove any MySQL or MariaDB server and its data so the
# lab starts from a clean system. Prints nothing on success.
set -eu

systemctl disable --now mysqld mariadb &>/dev/null || true

for pkg in mysql-server mariadb-server; do
	if rpm -q --quiet "$pkg"; then
		dnf -q -y remove "$pkg" >/dev/null
	fi
done

if [ -d /var/lib/mysql ]; then
	find /var/lib/mysql -mindepth 1 -delete
fi
