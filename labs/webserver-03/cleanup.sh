#!/bin/bash
# webserver-03 cleanup: undo setup and the solution. Packages the lab
# installed are removed again; packages that were already there stay, and
# httpd gets its earlier enabled and active state back.
STATE_FILE=/opt/linux-labs/state/webserver-03

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
	if [ "$(state_value httpd_installed)" = no ]; then
		# The lab installed httpd: stop it and remove it again
		systemctl disable --now httpd &>/dev/null || true
		dnf -y remove httpd &>/dev/null || true
	else
		# httpd was already there: restore its enabled and active state
		[ "$(state_value httpd_enabled)" = yes ] || systemctl disable httpd &>/dev/null || true
		if [ "$(state_value httpd_active)" = yes ]; then
			systemctl restart httpd &>/dev/null || true
		else
			systemctl stop httpd &>/dev/null || true
		fi
	fi
	if [ "$(state_value mod_ssl_installed)" = no ]; then
		dnf -y remove mod_ssl &>/dev/null || true
		# Default certificate that httpd-init generated on the first start
		rm -f /etc/pki/tls/certs/localhost.crt /etc/pki/tls/private/localhost.key
	fi
else
	# Lab was not started through labctl: only stop and disable httpd
	systemctl stop httpd &>/dev/null || true
	systemctl disable httpd &>/dev/null || true
fi

rm -f "$STATE_FILE"
exit 0
