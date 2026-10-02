#!/bin/bash
# webserver-01 setup: start with httpd stopped and disabled, and check
# that nothing else holds port 80. Prints nothing on success.
#
# A machine may already have httpd (servera keeps it from the clustering
# labs). It is not removed. The first run records whether httpd was
# installed, enabled and running, the firewall services and ports, and a
# copy of /etc/httpd and /var/www/html in /var/tmp/webserver-01.bak;
# cleanup.sh puts all of it back.
set -eu

STATE_FILE=/opt/linux-labs/state/webserver-01
bak=/var/tmp/webserver-01.bak

if [ ! -r "$STATE_FILE" ]; then
	rm -rf "$bak"
	mkdir -m 0700 "$bak"
	preinstalled=no
	was_enabled=no
	was_active=no
	if rpm -q httpd >/dev/null 2>&1; then
		preinstalled=yes
		systemctl is-enabled --quiet httpd 2>/dev/null && was_enabled=yes
		systemctl is-active --quiet httpd 2>/dev/null && was_active=yes
		keep=""
		for p in etc/httpd var/www/html; do
			[ -e "/$p" ] && keep="$keep $p"
		done
		# shellcheck disable=SC2086 # word splitting is intended
		tar --selinux --xattrs --acls -C / -cpf "$bak/files.tar" $keep
	fi
	fw_services=
	fw_ports=
	if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld 2>/dev/null; then
		fw_services=$(firewall-cmd --permanent --list-services 2>/dev/null || true)
		fw_ports=$(firewall-cmd --permanent --list-ports 2>/dev/null || true)
	fi
	mkdir -p "$(dirname "$STATE_FILE")"
	{
		echo "httpd_preinstalled=$preinstalled"
		echo "httpd_enabled=$was_enabled"
		echo "httpd_active=$was_active"
		echo "fw_services=$fw_services"
		echo "fw_ports=$fw_ports"
	} > "$STATE_FILE"
	chmod 644 "$STATE_FILE"
fi

preinstalled=$(sed -n 's/^httpd_preinstalled=//p' "$STATE_FILE")

# Not installed (or stopped), as the task starts
systemctl disable --now httpd >/dev/null 2>&1 || true
if [ "$preinstalled" != yes ] && rpm -q httpd >/dev/null 2>&1; then
	dnf -y remove httpd >/dev/null 2>&1 || {
		echo "Error: could not remove the httpd package." >&2
		exit 1
	}
fi

if [ -n "$(ss -H -tln 'sport = :80' 2>/dev/null)" ]; then
	echo "Error: another service already listens on TCP port 80." >&2
	exit 1
fi
