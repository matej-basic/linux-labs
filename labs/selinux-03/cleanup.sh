#!/bin/bash
# selinux-03 cleanup: undo the lab and the solution, leave SELinux
# enforcing. httpd and the SELinux tools go through pkg_restore; an httpd
# that was there before the lab keeps its enabled and running state.
source /opt/linux-labs/lib/packages.sh
STATE_FILE=/opt/linux-labs/state/selinux-03

httpd_was_enabled=no
httpd_was_active=no
# shellcheck disable=SC1090 # state file written by setup.sh
[ -r "$STATE_FILE" ] && . "$STATE_FILE"

systemctl disable --now httpd >/dev/null 2>&1 || true
rm -f /etc/httpd/conf.d/lab-port.conf

# SELinux settings made by the solution
semanage port -d -t http_port_t -p tcp 8081 >/dev/null 2>&1 || true
semanage fcontext -l -C 2>/dev/null | awk '$1 ~ "^/webapp" { print $1 }' |
	while read -r p; do semanage fcontext -d "$p" >/dev/null 2>&1 || true; done
semodule -r myapp_custom >/dev/null 2>&1 || true
rm -rf /webapp

httpd_before=yes
if ! pkg_was_installed selinux-03 httpd; then
	httpd_before=no
	# New httpd: delete what the apache account owns, so that
	# pkg_restore can remove the account
	rm -rf /var/log/httpd/* /var/cache/httpd
fi

rc=0
pkg_restore selinux-03 || rc=1

# Empty directories rpm leaves behind after removing a new httpd
if [ "$httpd_before" = no ] && ! rpm -q httpd >/dev/null 2>&1; then
	rmdir /etc/httpd/conf.modules.d /etc/httpd 2>/dev/null || true
fi

# An httpd from before the lab gets its service state back
if [ "$httpd_before" = yes ] && rpm -q httpd >/dev/null 2>&1; then
	if [ "$httpd_was_enabled" = yes ]; then
		systemctl enable httpd >/dev/null 2>&1 || true
	fi
	if [ "$httpd_was_active" = yes ]; then
		systemctl start httpd >/dev/null 2>&1 || true
	fi
fi

if [ "$(getenforce 2>/dev/null)" = Permissive ]; then
	setenforce 1 || true
fi

rm -f "$STATE_FILE"
exit "$rc"
