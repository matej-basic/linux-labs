#!/bin/bash
# webserver-01 setup: start without Apache. httpd is removed if it is
# installed, and nothing else may hold port 80. Prints nothing on success.
#
# The first run records the package set (pkg_snapshot), whether httpd
# was installed, enabled and running, the firewall services and ports,
# and, when httpd was installed, a copy of /etc/httpd, /var/www and
# /var/log/httpd in /var/tmp/webserver-01.bak. cleanup.sh puts all of it
# back: pkg_restore installs httpd again if it was there before.
set -eu
source /opt/linux-labs/lib/packages.sh

STATE_FILE=/opt/linux-labs/state/webserver-01
bak=/var/tmp/webserver-01.bak
dirs="etc/httpd var/www var/log/httpd"

pkg_snapshot webserver-01

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
		for p in $dirs; do
			[ -e "/$p" ] && keep="$keep $p"
		done
		if [ -n "$keep" ]; then
			# shellcheck disable=SC2086 # word splitting is intended
			tar --selinux --xattrs --acls -C / -cpf "$bak/files.tar" $keep
		fi
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

# No httpd, as the task starts
systemctl disable --now httpd >/dev/null 2>&1 || true
if rpm -q httpd >/dev/null 2>&1; then
	dnf -y remove httpd </dev/null >/dev/null 2>&1 || {
		echo "Error: could not remove the httpd package." >&2
		exit 1
	}
fi

# Configuration, content and logs of the removed httpd or of an earlier
# attempt (a recorded copy is in $bak). Directories that a package still
# owns stay.
for p in $dirs; do
	if [ -d "/$p" ] && ! rpm -qf "/$p" >/dev/null 2>&1; then
		rm -rf "/${p:?}"
	fi
done

if [ -n "$(ss -H -tln 'sport = :80' 2>/dev/null)" ]; then
	echo "Error: another service already listens on TCP port 80." >&2
	exit 1
fi
