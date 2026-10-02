#!/bin/bash
# mysql-01 cleanup: stop the server and restore the package set of the
# first start (pkg_restore): the MySQL server the lab installed goes with
# its dependencies, and a server package that was there before comes
# back. Then put back what setup.sh recorded: the data directory, the
# option files, the log directory, root's client files and the service
# state. When the package set cannot be restored, the records stay for
# the next reset and the exit status is 1.
source /opt/linux-labs/lib/packages.sh

STATE_FILE=/opt/linux-labs/state/mysql-01
bak=/var/tmp/mysql-01.bak
datadir=/var/lib/mysql
paths="etc/my.cnf etc/my.cnf.d var/log/mysql root/.my.cnf root/.mysql_history"

state_value() {
	[ -r "$STATE_FILE" ] || return 0
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}

systemctl disable --now mysqld mariadb </dev/null >/dev/null 2>&1

rc=0
pkg_restore mysql-01 || rc=1

# setup.sh never ran: nothing else to undo
[ -r "$STATE_FILE" ] || exit "$rc"

# Data directory: the saved one, else empty or gone. A saved directory
# that is no longer in $bak was put back by an earlier reset.
if [ -d "$bak/datadir" ]; then
	rm -rf "$datadir"
	mv "$bak/datadir" "$datadir" || exit 1
	restorecon -R "$datadir" 2>/dev/null
elif [ "$(state_value datadir)" != yes ] && [ -d "$datadir" ]; then
	find "$datadir" -mindepth 1 -delete 2>/dev/null
	rpm -qf "$datadir" >/dev/null 2>&1 || rmdir "$datadir" 2>/dev/null
fi

# Option files, log directory and root's client files as they were
for p in $paths; do
	[ -e "/$p" ] || continue
	rpm -qf "/$p" >/dev/null 2>&1 && [ ! -f "$bak/files.tar" ] && continue
	rm -rf "/${p:?}"
done
rm -f /etc/my.cnf.rpmsave /etc/my.cnf.d/*.rpmsave
if [ -f "$bak/files.tar" ]; then
	tar --selinux --xattrs --acls -C / -xpf "$bak/files.tar" || exit 1
	for p in $paths; do
		[ -e "/$p" ] && restorecon -R "/$p" 2>/dev/null
	done
fi

for u in mysqld mariadb; do
	systemctl cat "$u" </dev/null >/dev/null 2>&1 || continue
	[ "$(state_value "${u}_enabled")" = yes ] \
		&& systemctl enable "$u" </dev/null >/dev/null 2>&1
	[ "$(state_value "${u}_active")" = yes ] \
		&& systemctl start "$u" </dev/null >/dev/null 2>&1
done

if [ "$rc" -eq 0 ]; then
	rm -rf "$bak"
	rm -f "$STATE_FILE"
fi
exit "$rc"
