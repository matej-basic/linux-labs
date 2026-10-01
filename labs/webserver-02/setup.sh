#!/bin/bash
# webserver-02 setup: remove leftovers of an earlier run and record whether
# httpd was already installed, so cleanup removes only what the lab added.
# Prints nothing on success.
set -eu

STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/webserver-02"

mkdir -p "$STATE_DIR"

# Record the original httpd state once; a rerun keeps the first record.
if [ ! -f "$STATE_FILE" ]; then
	pre=no
	act=no
	ena=no
	if rpm -q httpd &>/dev/null; then
		pre=yes
		systemctl is-active --quiet httpd && act=yes
		systemctl is-enabled --quiet httpd && ena=yes
	fi
	{
		echo "httpd_installed=$pre"
		echo "httpd_active=$act"
		echo "httpd_enabled=$ena"
	} > "$STATE_FILE"
	chmod 644 "$STATE_FILE"
fi

# Remove what an earlier run or the solution left behind
rm -rf /var/www/lab2
for f in /etc/httpd/conf.d/*.conf; do
	[ -f "$f" ] || continue
	if grep -qE 'lab2\.local|/var/www/lab2' "$f"; then
		rm -f "$f"
	fi
done
sed -i '/lab2\.local/d' /etc/hosts

# Drop a stale lab2 virtual host from a running server
if systemctl is-active --quiet httpd; then
	systemctl restart httpd &>/dev/null || true
fi
exit 0
