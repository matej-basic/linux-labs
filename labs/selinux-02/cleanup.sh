#!/bin/bash
# selinux-02 cleanup: removes /webapp, the virtual host, the file context
# rules and (if the lab installed it) httpd. Leaves SELinux enforcing.
STATE_FILE=/opt/linux-labs/state/selinux-02

preinstalled=no
[ -r "$STATE_FILE" ] && preinstalled=$(sed -n 's/^httpd_preinstalled=//p' "$STATE_FILE")

rm -f /etc/httpd/conf.d/myapp.conf /var/log/httpd/myapp-*.log

if rpm -q httpd >/dev/null 2>&1; then
	if [ "$preinstalled" = yes ]; then
		systemctl try-restart httpd >/dev/null 2>&1 || true
	else
		systemctl disable --now httpd >/dev/null 2>&1 || true
		dnf -y -q remove httpd >/dev/null 2>&1 || true
	fi
fi

# Remove every local file context rule for /webapp
if command -v semanage >/dev/null 2>&1; then
	while read -r path; do
		[ -n "$path" ] && semanage fcontext -d "$path" >/dev/null 2>&1 || true
	done < <(semanage fcontext -l -C 2>/dev/null | awk '$1 ~ /^\/webapp/ { print $1 }')
fi

rm -rf /webapp

# SELinux enforcing, now and after a reboot
if command -v getenforce >/dev/null 2>&1 && [ "$(getenforce 2>/dev/null)" != Disabled ]; then
	setenforce 1 >/dev/null 2>&1 || true
	sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config 2>/dev/null || true
fi

rm -f "$STATE_FILE"
exit 0
