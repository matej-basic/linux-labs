#!/bin/bash
# postgres-01 cleanup: stop the server and restore the package set of the
# first start (pkg_restore): the PostgreSQL the lab installed goes with
# its dependencies and the user postgres, and packages that were there
# before come back. Then put back what setup.sh recorded: /var/lib/pgsql
# and the service state. When the package set cannot be restored, the
# records stay for the next reset and the exit status is 1.
source /opt/linux-labs/lib/packages.sh

STATE_FILE=/opt/linux-labs/state/postgres-01
bak=/var/tmp/postgres-01.bak
home=/var/lib/pgsql

state_value() {
	[ -r "$STATE_FILE" ] || return 0
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}

systemctl disable --now postgresql </dev/null >/dev/null 2>&1
rm -rf /etc/systemd/system/postgresql.service.d
systemctl daemon-reload </dev/null >/dev/null 2>&1

# Delete the student's /var/lib/pgsql before pkg_restore, so that a user
# postgres the lab created owns no files and the helper can remove it. A
# saved /var/lib/pgsql that is no longer in $bak was put back by an
# earlier reset and stays.
if [ -d "$bak/pgsql" ]; then
	rm -rf "$home"
elif [ -r "$STATE_FILE" ]; then
	[ "$(state_value home)" = yes ] || rm -rf "$home"
elif ! pkg_was_installed postgres-01 postgresql-server; then
	rm -rf "$home"
fi

rc=0
pkg_restore postgres-01 || rc=1

# setup.sh never ran: nothing else to undo
[ -r "$STATE_FILE" ] || exit "$rc"

# /var/lib/pgsql as it was (data directory included)
if [ -d "$bak/pgsql" ]; then
	rm -rf "$home"
	mv "$bak/pgsql" "$home" || exit 1
	restorecon -R "$home" 2>/dev/null
fi

systemctl daemon-reload </dev/null >/dev/null 2>&1
if systemctl cat postgresql </dev/null >/dev/null 2>&1; then
	[ "$(state_value enabled)" = yes ] \
		&& systemctl enable postgresql </dev/null >/dev/null 2>&1
	[ "$(state_value active)" = yes ] \
		&& systemctl start postgresql </dev/null >/dev/null 2>&1
fi

if [ "$rc" -eq 0 ]; then
	rm -rf "$bak"
	rm -f "$STATE_FILE"
fi
exit "$rc"
