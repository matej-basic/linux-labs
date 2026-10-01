#!/bin/bash
# mysql-01 cleanup: stop MySQL, remove the server package and its data.
systemctl disable --now mysqld mariadb &>/dev/null || true

for pkg in mysql-server mariadb-server; do
	if rpm -q --quiet "$pkg"; then
		dnf -q -y remove "$pkg" >/dev/null 2>&1 || true
	fi
done

if [ -d /var/lib/mysql ]; then
	find /var/lib/mysql -mindepth 1 -delete 2>/dev/null || true
fi
exit 0
