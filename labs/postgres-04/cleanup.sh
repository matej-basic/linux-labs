#!/bin/bash
# postgres-04 cleanup: stop and disable postgresql, remove the lab's
# cluster, put the local SELinux customizations (port and file context
# rules, booleans), the policy modules and the SELinux mode back as
# setup.sh recorded them at the first start, and restore the package set
# (pkg_restore), which also restores the module stream. /var/lib/pgsql
# goes before pkg_restore, so a user postgres the lab created owns no
# files and is removed with the package. A /var/lib/pgsql from before
# the lab comes back afterwards, with the service state. When the
# package set cannot be restored, the records stay for the next reset
# and the exit status is 1.
source /opt/linux-labs/lib/packages.sh

LAB=postgres-04
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
REC_DIR="$STATE_DIR/$LAB.d"
bak=/var/tmp/$LAB.bak
home=/var/lib/pgsql

state_value() {
	[ -r "$STATE_FILE" ] || return 0
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}

# The same as in setup.sh: local SELinux customizations back to the
# recorded state, new policy modules at priority 400 removed
selinux_restore() {
	local rec="$REC_DIR/semanage.export" now line m before
	[ -r "$rec" ] || return 0
	command -v semanage >/dev/null 2>&1 || return 0
	now=$(semanage export 2>/dev/null) || return 0
	printf '%s\n' "$now" | grep -E '^(fcontext|port) -a ' |
		grep -vxF -f "$rec" | sed 's/^\([a-z]*\) -a /\1 -d /' |
		while IFS= read -r line; do
			printf '%s\n' "$line" | semanage import >/dev/null 2>&1 || true
		done
	grep -E '^(fcontext|port) -a ' "$rec" |
		grep -vxF -f <(printf '%s\n' "$now") |
		while IFS= read -r line; do
			printf '%s\n' "$line" | semanage import >/dev/null 2>&1 || true
		done
	if [ "$(printf '%s\n' "$now" | grep '^boolean -m ' | sort)" != \
		"$(grep '^boolean -m ' "$rec" | sort)" ]; then
		semanage boolean -D >/dev/null 2>&1 || true
		grep '^boolean -m ' "$rec" | while IFS= read -r line; do
			printf '%s\n' "$line" | semanage import >/dev/null 2>&1 || true
		done
	fi
	getsebool -a 2>/dev/null | grep -vxF -f "$REC_DIR/booleans" |
		awk '{ print $1 }' | while read -r m; do
			line=$(awk -v b="$m" '$1 == b { print $3 }' "$REC_DIR/booleans")
			[ -n "$line" ] && setsebool "$m" "$line" >/dev/null 2>&1
			true
		done
	before=$(state_value modules)
	for m in $(semodule -lfull 2>/dev/null | awk '$1 == 400 { print $2 }'); do
		case " $before " in
		*" $m "*) ;;
		*) semodule -X 400 -r "$m" >/dev/null 2>&1 || true ;;
		esac
	done
}

systemctl disable --now postgresql >/dev/null 2>&1
systemctl reset-failed postgresql >/dev/null 2>&1

if [ -r "$STATE_FILE" ]; then
	# SELinux, before pkg_restore can remove semanage
	if command -v getenforce >/dev/null 2>&1 && [ "$(getenforce 2>/dev/null)" != Disabled ]; then
		selinux_restore
		setenforce 1 >/dev/null 2>&1
		cfg=$(state_value selinux_cfg)
		if [ -n "$cfg" ]; then
			sed -i "s/^SELINUX=.*/SELINUX=$cfg/" /etc/selinux/config
		fi
	fi
fi

# The lab's cluster and server log. A /var/lib/pgsql from before the
# lab waits in $bak. Without a state file, the lab may have installed
# the server before it failed.
if [ -r "$STATE_FILE" ] || [ -d "$bak/pgsql" ] ||
	! pkg_was_installed "$LAB" postgresql-server; then
	rm -rf "$home"
fi

rc=0
pkg_restore "$LAB" || rc=1

# setup.sh never recorded anything: nothing else to undo
if [ ! -r "$STATE_FILE" ]; then
	[ "$rc" -eq 0 ] && rm -rf "$REC_DIR"
	exit "$rc"
fi

# /var/lib/pgsql as it was (data directory included). After a failed
# pkg_restore it stays in $bak, so the next reset still finds it.
if [ "$rc" -eq 0 ] && [ -d "$bak/pgsql" ]; then
	rm -rf "$home"
	if mv "$bak/pgsql" "$home"; then
		restorecon -R "$home" >/dev/null 2>&1
	else
		rc=1
	fi
fi

# A server from before the lab gets its service state back
if rpm -q postgresql-server >/dev/null 2>&1; then
	[ "$(state_value pg_was_enabled)" = yes ] &&
		systemctl enable postgresql >/dev/null 2>&1
	[ "$(state_value pg_was_active)" = yes ] &&
		systemctl start postgresql >/dev/null 2>&1
fi

if [ "$rc" -eq 0 ]; then
	rm -rf "$REC_DIR" "$bak"
	rm -f "$STATE_FILE" "$STATE_FILE.tmp"
fi
exit "$rc"
