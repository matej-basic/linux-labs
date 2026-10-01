#!/bin/bash
# webserver-02 cleanup: undo setup and the solution.
STATE_FILE=/opt/linux-labs/state/webserver-02

state_value() {
	[ -r "$STATE_FILE" ] || return 0
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}

rm -rf /var/www/lab2
for f in /etc/httpd/conf.d/*.conf; do
	[ -f "$f" ] || continue
	if grep -qE 'lab2\.local|/var/www/lab2' "$f"; then
		rm -f "$f"
	fi
done
sed -i '/lab2\.local/d' /etc/hosts

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
else
	# Lab was not started through labctl: only reload a running server
	systemctl try-restart httpd &>/dev/null || true
fi

rm -f "$STATE_FILE"
exit 0
