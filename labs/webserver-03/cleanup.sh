#!/bin/bash
# webserver-03 cleanup: stop httpd, remove the lab3 virtual host, content,
# certificate and hosts entry, and restore the package set of the first
# start (pkg_restore): httpd, mod_ssl and their dependencies go if the
# lab installed them, and come back if they were installed before. Then
# put back what setup.sh recorded: /etc/httpd, /var/www and
# /var/log/httpd of a httpd that was there before, and its service state.
# When the package set cannot be restored, the records stay for the next
# reset and the exit status is 1.
source /opt/linux-labs/lib/packages.sh

STATE_FILE=/opt/linux-labs/state/webserver-03
bak=/var/tmp/webserver-03.bak
dirs="etc/httpd var/www var/log/httpd"

state_value() {
	[ -r "$STATE_FILE" ] || return 0
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}

systemctl disable --now httpd >/dev/null 2>&1 || true

rm -rf /var/www/lab3
rm -f /etc/httpd/conf.d/lab3.conf
rm -f /etc/pki/tls/certs/lab3.crt /etc/pki/tls/private/lab3.key
sed -i '/lab3\.local/d' /etc/hosts

httpd_before=yes
if ! pkg_was_installed webserver-03 httpd; then
	httpd_before=no
	# New httpd: delete what the apache account owns, so that
	# pkg_restore can remove the account
	rm -rf /var/log/httpd/* /var/cache/httpd
fi

rc=0
pkg_restore webserver-03 || rc=1

if [ "$httpd_before" = no ] && ! rpm -q httpd >/dev/null 2>&1; then
	# Empty directories rpm leaves behind after removing a new httpd
	rmdir /etc/httpd/conf.modules.d /etc/httpd 2>/dev/null || true
	# The default certificate that httpd-init created on the first start
	if [ "$(state_value default_cert_present)" = no ]; then
		rm -f /etc/pki/tls/certs/localhost.crt /etc/pki/tls/private/localhost.key
	fi
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
