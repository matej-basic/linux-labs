#!/bin/bash
# webserver-03 setup: start without Apache. httpd and mod_ssl are removed
# if they are installed, and leftovers of an earlier run are cleared.
# Prints nothing on success.
#
# The first run records the package set (pkg_snapshot), whether httpd
# was installed, enabled and running, whether the default certificate
# existed, and, when httpd was installed, a copy of /etc/httpd,
# /var/www and /var/log/httpd in /var/tmp/webserver-03.bak. cleanup.sh
# puts all of it back: pkg_restore installs httpd and mod_ssl again if
# they were there before.
set -eu
source /opt/linux-labs/lib/packages.sh

STATE_FILE=/opt/linux-labs/state/webserver-03
bak=/var/tmp/webserver-03.bak
dirs="etc/httpd var/www var/log/httpd"

pkg_snapshot webserver-03

if [ ! -r "$STATE_FILE" ]; then
	rm -rf "$bak"
	mkdir -m 0700 "$bak"
	preinstalled=no
	was_enabled=no
	was_active=no
	crt_pre=no
	if [ -e /etc/pki/tls/certs/localhost.crt ] || [ -e /etc/pki/tls/private/localhost.key ]; then
		crt_pre=yes
	fi
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
	mkdir -p "$(dirname "$STATE_FILE")"
	{
		echo "httpd_preinstalled=$preinstalled"
		echo "httpd_enabled=$was_enabled"
		echo "httpd_active=$was_active"
		echo "default_cert_present=$crt_pre"
	} > "$STATE_FILE"
	chmod 644 "$STATE_FILE"
fi

# No httpd and no mod_ssl, as the task starts
systemctl disable --now httpd >/dev/null 2>&1 || true
for p in mod_ssl httpd; do
	if rpm -q "$p" >/dev/null 2>&1; then
		dnf -y remove "$p" </dev/null >/dev/null 2>&1 || {
			echo "Error: could not remove the $p package." >&2
			exit 1
		}
	fi
done

# Configuration, content and logs of the removed httpd or of an earlier
# attempt (a recorded copy is in $bak). Directories that a package still
# owns stay.
for p in $dirs; do
	if [ -d "/$p" ] && ! rpm -qf "/$p" >/dev/null 2>&1; then
		rm -rf "/${p:?}"
	fi
done
rm -f /etc/pki/tls/certs/lab3.crt /etc/pki/tls/private/lab3.key
sed -i '/lab3\.local/d' /etc/hosts
exit 0
