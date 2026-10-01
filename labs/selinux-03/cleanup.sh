#!/bin/bash
# selinux-03 cleanup: undo the lab and the solution, leave SELinux enforcing.
STATE_FILE=/opt/linux-labs/state/selinux-03

httpd_preinstalled=no
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

# Restore the state from before the lab
if [ "$httpd_preinstalled" = no ]; then
	dnf -y -q remove httpd >/dev/null 2>&1 || true
else
	[ "$httpd_was_enabled" = yes ] && systemctl enable httpd >/dev/null 2>&1
	[ "$httpd_was_active" = yes ] && systemctl start httpd >/dev/null 2>&1
fi

if [ "$(getenforce 2>/dev/null)" = Permissive ]; then
	setenforce 1 || true
fi

rm -f "$STATE_FILE"
exit 0
