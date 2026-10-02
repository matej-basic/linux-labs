#!/bin/bash
# selinux-02 cleanup: removes /webapp, the virtual host and the file
# context rules. httpd and the SELinux tools go through pkg_restore; an
# httpd that was there before the lab keeps its enabled and running
# state. Leaves SELinux enforcing.
source /opt/linux-labs/lib/packages.sh
STATE_FILE=/opt/linux-labs/state/selinux-02

was_enabled=no
was_active=no
if [ -r "$STATE_FILE" ]; then
	was_enabled=$(sed -n 's/^httpd_enabled=//p' "$STATE_FILE")
	was_active=$(sed -n 's/^httpd_active=//p' "$STATE_FILE")
fi

rm -f /etc/httpd/conf.d/myapp.conf /var/log/httpd/myapp-*.log

# Remove every local file context rule for /webapp
if command -v semanage >/dev/null 2>&1; then
	while read -r path; do
		[ -n "$path" ] && semanage fcontext -d "$path" >/dev/null 2>&1 || true
	done < <(semanage fcontext -l -C 2>/dev/null | awk '$1 ~ /^\/webapp/ { print $1 }')
fi

rm -rf /webapp

httpd_before=yes
if ! pkg_was_installed selinux-02 httpd; then
	httpd_before=no
	# New httpd: stop it and delete what the apache account owns, so
	# that pkg_restore can remove the account
	systemctl disable --now httpd >/dev/null 2>&1 || true
	rm -rf /var/log/httpd/* /var/cache/httpd
fi

rc=0
pkg_restore selinux-02 || rc=1

# Empty directories rpm leaves behind after removing a new httpd
if [ "$httpd_before" = no ] && ! rpm -q httpd >/dev/null 2>&1; then
	rmdir /etc/httpd/conf.modules.d /etc/httpd 2>/dev/null || true
fi

# An httpd from before the lab gets its service state back
if [ "$httpd_before" = yes ] && rpm -q httpd >/dev/null 2>&1; then
	if [ "$was_enabled" = yes ]; then
		systemctl enable httpd >/dev/null 2>&1 || true
	else
		systemctl disable httpd >/dev/null 2>&1 || true
	fi
	if [ "$was_active" = yes ]; then
		systemctl restart httpd >/dev/null 2>&1 || true
	else
		systemctl stop httpd >/dev/null 2>&1 || true
	fi
fi

# SELinux enforcing, now and after a reboot
if command -v getenforce >/dev/null 2>&1 && [ "$(getenforce 2>/dev/null)" != Disabled ]; then
	setenforce 1 >/dev/null 2>&1 || true
	sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config 2>/dev/null || true
fi

rm -f "$STATE_FILE"
exit "$rc"
