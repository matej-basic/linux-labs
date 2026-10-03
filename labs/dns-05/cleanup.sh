#!/bin/bash
# dns-05 cleanup: removes the immutable and append-only attributes from
# /etc/resolv.conf, puts the NetworkManager configuration back as it was
# at the first start (90-lab.conf and every other file added to the
# conf.d directories of /etc and /run during the lab removed, changed
# files and NetworkManager.conf written back), restores /etc/hosts and
# /etc/resolv.conf (file or symlink) exactly, starts NetworkManager if
# it was stopped and reloads its configuration and DNS, then removes the
# state and restores the package set. The connection profile of the
# default-route interface is never touched. Safe to run repeatedly and
# on a lab that was never started.
#
# setup.sh runs this script with --leftovers on a restart: it then
# restores the configuration and keeps the record of the first start
# and the package snapshot.
source /opt/linux-labs/lib/packages.sh

LAB="dns-05"
STATE_DIR=/opt/linux-labs/state
STATE=$STATE_DIR/$LAB
ORIG=$STATE_DIR/$LAB.orig
LABCONF=/etc/NetworkManager/conf.d/90-lab.conf

leftovers_only=no
[ "${1:-}" = --leftovers ] && leftovers_only=yes

# Write file $1 to $2 only when the content differs
put_back() {
	[ ! -L "$2" ] && cmp -s "$1" "$2" 2>/dev/null && return 0
	chattr -i -a "$2" >/dev/null 2>&1 || true
	if [ -L "$2" ] || [ ! -f "$2" ]; then
		rm -f "$2"
		cp -p "$1" "$2"
	else
		cat "$1" > "$2"
	fi
	restorecon "$2" >/dev/null 2>&1 || true
}

for f in /etc/resolv.conf "$(readlink -f /etc/resolv.conf 2>/dev/null)"; do
	[ -n "$f" ] && [ -f "$f" ] && chattr -i -a "$f" >/dev/null 2>&1
done
rm -f "$LABCONF"

if [ -f "$ORIG/done" ]; then
	# NetworkManager configuration
	for f in /etc/NetworkManager/conf.d/*; do
		[ -e "$f" ] || continue
		n=${f##*/}
		if [ -f "$ORIG/conf.d/$n" ]; then
			put_back "$ORIG/conf.d/$n" "$f"
		else
			rm -rf "$f"
		fi
	done
	for f in "$ORIG"/conf.d/*; do
		[ -f "$f" ] || continue
		[ -e "/etc/NetworkManager/conf.d/${f##*/}" ] ||
			put_back "$f" "/etc/NetworkManager/conf.d/${f##*/}"
	done
	if [ -f "$ORIG/NetworkManager.conf" ]; then
		put_back "$ORIG/NetworkManager.conf" /etc/NetworkManager/NetworkManager.conf
	fi
	if [ -f "$ORIG/run-conf.d" ]; then
		for f in /run/NetworkManager/conf.d/*; do
			[ -e "$f" ] || continue
			grep -qxF "${f##*/}" "$ORIG/run-conf.d" || rm -rf "$f"
		done
	fi

	# /etc/hosts
	[ ! -f "$ORIG/hosts" ] || put_back "$ORIG/hosts" /etc/hosts

	# /etc/resolv.conf as a symlink or a file
	if [ -f "$ORIG/resolv.link" ]; then
		target=$(cat "$ORIG/resolv.link")
		if [ "$(readlink /etc/resolv.conf 2>/dev/null)" != "$target" ]; then
			rm -f /etc/resolv.conf
			ln -s "$target" /etc/resolv.conf
		fi
	elif [ -f "$ORIG/resolv.conf" ]; then
		put_back "$ORIG/resolv.conf" /etc/resolv.conf
	fi

	systemctl is-active --quiet NetworkManager ||
		systemctl start NetworkManager >/dev/null 2>&1 || true
fi

# Configuration and DNS only; connections are not touched
if systemctl is-active --quiet NetworkManager; then
	nmcli general reload >/dev/null 2>&1 || true
	sleep 1
fi

[ "$leftovers_only" = yes ] && exit 0

rc=0
pkg_restore "$LAB" || rc=1
rm -rf "$STATE"
[ "$rc" -eq 0 ] && rm -rf "$ORIG"
exit "$rc"
