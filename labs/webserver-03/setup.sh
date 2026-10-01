#!/bin/bash
# webserver-03 setup: remove leftovers of an earlier run and record whether
# httpd and mod_ssl were already installed, so cleanup removes only what the
# lab added. Prints nothing on success.
set -eu

STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/webserver-03"

mkdir -p "$STATE_DIR"

# Record the original state once; a rerun keeps the first record.
if [ ! -f "$STATE_FILE" ]; then
	httpd_pre=no
	ssl_pre=no
	act=no
	ena=no
	rpm -q mod_ssl &>/dev/null && ssl_pre=yes
	if rpm -q httpd &>/dev/null; then
		httpd_pre=yes
		systemctl is-active --quiet httpd && act=yes
		systemctl is-enabled --quiet httpd && ena=yes
	fi
	{
		echo "httpd_installed=$httpd_pre"
		echo "mod_ssl_installed=$ssl_pre"
		echo "httpd_active=$act"
		echo "httpd_enabled=$ena"
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
