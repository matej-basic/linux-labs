#!/bin/bash
# webserver-03 cleanup: undo setup and the solution. Packages the lab
# installed are removed again; packages that were already there stay, and
# httpd gets its earlier files, enabled state and active state back.
STATE_FILE=/opt/linux-labs/state/webserver-03
bak=/var/tmp/webserver-03.bak

state_value() {
	[ -r "$STATE_FILE" ] || return 0
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}

rm -rf /var/www/lab3
rm -f /etc/httpd/conf.d/lab3.conf
rm -f /etc/pki/tls/certs/lab3.crt
rm -f /etc/pki/tls/private/lab3.key
sed -i '/lab3\.local/d' /etc/hosts

if [ -r "$STATE_FILE" ]; then
	systemctl stop httpd &>/dev/null || true
	if [ "$(state_value mod_ssl_installed)" = no ]; then
		dnf -y remove mod_ssl &>/dev/null || true
		# The default certificate httpd-init generated on the first start
		if [ "$(state_value default_cert_present)" = no ]; then
			rm -f /etc/pki/tls/certs/localhost.crt /etc/pki/tls/private/localhost.key
		fi
	fi
	if [ "$(state_value httpd_installed)" = no ]; then
		# The lab installed httpd: disable it and remove it again
		systemctl disable httpd &>/dev/null || true
		dnf -y remove httpd &>/dev/null || true
	else
		# httpd was already there: delete files the lab added, restore the
		# recorded /etc/httpd and /var/www/html, then the service state
		if [ -f "$bak/files.tar" ]; then
			tar -tf "$bak/files.tar" | sed 's|/$||' | sort > "$bak/list"
			while read -r f; do
				f=${f#/}
				grep -qxF "$f" "$bak/list" || rm -f "/$f"
			done < <(find /etc/httpd /var/www/html \( -type f -o -type l \) 2>/dev/null)
			tar --selinux --xattrs --acls -C / -xpf "$bak/files.tar"
		fi
		[ "$(state_value httpd_enabled)" = yes ] || systemctl disable httpd &>/dev/null || true
		if [ "$(state_value httpd_active)" = yes ]; then
			systemctl restart httpd &>/dev/null || true
		fi
	fi
else
	# Lab was not started through labctl: only stop and disable httpd
	systemctl stop httpd &>/dev/null || true
	systemctl disable httpd &>/dev/null || true
fi

rm -rf "$bak"
rm -f "$STATE_FILE"
exit 0
