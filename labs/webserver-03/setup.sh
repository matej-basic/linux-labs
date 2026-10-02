#!/bin/bash
# webserver-03 setup: remove leftovers of an earlier run and record whether
# httpd and mod_ssl were already installed, so cleanup removes only what the
# lab added. Prints nothing on success.
set -eu

STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/webserver-03"

mkdir -p "$STATE_DIR"

# Record the original state once; a rerun keeps the first record. If httpd
# is already installed (servera keeps it from the clustering labs), also
# keep a copy of /etc/httpd and /var/www/html in /var/tmp/webserver-03.bak
# so cleanup.sh can put them back.
if [ ! -f "$STATE_FILE" ]; then
	bak=/var/tmp/webserver-03.bak
	rm -rf "$bak"
	mkdir -m 0700 "$bak"
	httpd_pre=no
	ssl_pre=no
	act=no
	ena=no
	crt_pre=no
	rpm -q mod_ssl &>/dev/null && ssl_pre=yes
	[ -e /etc/pki/tls/certs/localhost.crt ] || [ -e /etc/pki/tls/private/localhost.key ] && crt_pre=yes
	if rpm -q httpd &>/dev/null; then
		httpd_pre=yes
		systemctl is-active --quiet httpd && act=yes
		systemctl is-enabled --quiet httpd && ena=yes
		keep=""
		for p in etc/httpd var/www/html; do
			[ -e "/$p" ] && keep="$keep $p"
		done
		# shellcheck disable=SC2086 # word splitting is intended
		tar --selinux --xattrs --acls -C / -cpf "$bak/files.tar" $keep
	fi
	{
		echo "httpd_installed=$httpd_pre"
		echo "mod_ssl_installed=$ssl_pre"
		echo "httpd_active=$act"
		echo "httpd_enabled=$ena"
		echo "default_cert_present=$crt_pre"
	} > "$STATE_FILE"
	chmod 644 "$STATE_FILE"
fi

# Remove what an earlier run or the solution left behind
systemctl stop httpd &>/dev/null || true
rm -rf /var/www/lab3
rm -f /etc/httpd/conf.d/lab3.conf
rm -f /etc/pki/tls/certs/lab3.crt
rm -f /etc/pki/tls/private/lab3.key
sed -i '/lab3\.local/d' /etc/hosts
exit 0
