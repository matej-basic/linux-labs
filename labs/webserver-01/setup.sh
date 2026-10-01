#!/bin/bash
# webserver-01 setup: start without Apache. Removes httpd if it is
# installed and checks that nothing else holds port 80. Prints nothing
# on success.
set -eu

systemctl disable --now httpd >/dev/null 2>&1 || true
if rpm -q httpd >/dev/null 2>&1; then
	dnf -y remove httpd >/dev/null 2>&1 || {
		echo "Error: could not remove the httpd package." >&2
		exit 1
	}
fi

if [ -n "$(ss -H -tln 'sport = :80' 2>/dev/null)" ]; then
	echo "Error: another service already listens on TCP port 80." >&2
	exit 1
fi
