#!/bin/bash
# webserver-02 cleanup: stop httpd, remove the lab2 virtual host, content
# and hosts entry, and restore the package set of the first start
# (pkg_restore): httpd and its dependencies go if the lab installed
# them, and come back if httpd was installed before. Then put back what
# setup.sh recorded: /etc/httpd, /var/www and /var/log/httpd of a httpd
# that was there before, and its service state. When the package set
# cannot be restored, the records stay for the next reset and the exit
# status is 1.
source /opt/linux-labs/lib/packages.sh

STATE_FILE=/opt/linux-labs/state/webserver-02
bak=/var/tmp/webserver-02.bak
dirs="etc/httpd var/www var/log/httpd"

state_value() {
	[ -r "$STATE_FILE" ] || return 0
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}

systemctl disable --now httpd >/dev/null 2>&1 || true

rm -rf /var/www/lab2
for f in /etc/httpd/conf.d/*.conf; do
	[ -f "$f" ] || continue
	if grep -qE 'lab2\.local|/var/www/lab2' "$f"; then
		rm -f "$f"
	fi
done
sed -i '/lab2\.local/d' /etc/hosts

httpd_before=yes
if ! pkg_was_installed webserver-02 httpd; then
	httpd_before=no
	# New httpd: delete what the apache account owns, so that
	# pkg_restore can remove the account
	rm -rf /var/log/httpd/* /var/cache/httpd
fi

rc=0
pkg_restore webserver-02 || rc=1

if [ "$httpd_before" = no ] && ! rpm -q httpd >/dev/null 2>&1; then
	# Empty directories rpm leaves behind after removing a new httpd
	rmdir /etc/httpd/conf.modules.d /etc/httpd 2>/dev/null || true
fi

if [ "$(state_value httpd_preinstalled)" = yes ]; then
	if [ -f "$bak/files.tar" ]; then
		# Delete files the lab added, then restore the recorded ones
		tar -tf "$bak/files.tar" | sed 's|/$||' | sort > "$bak/list"
		for p in $dirs; do
			[ -d "/$p" ] || continue
			find "/$p" \( -type f -o -type l \) 2>/dev/null
		done | while read -r f; do
			f=${f#/}
			grep -qxF "$f" "$bak/list" || rm -f "/$f"
		done
		tar --selinux --xattrs --acls -C / -xpf "$bak/files.tar"
	fi
	if [ "$(state_value httpd_enabled)" = yes ]; then
		systemctl enable httpd >/dev/null 2>&1 || true
	fi
	if [ "$(state_value httpd_active)" = yes ]; then
		systemctl restart httpd >/dev/null 2>&1 || true
	fi
fi

if [ "$rc" -eq 0 ]; then
	rm -rf "$bak"
	rm -f "$STATE_FILE"
fi
exit "$rc"
