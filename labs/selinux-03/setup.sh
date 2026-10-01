#!/bin/bash
# selinux-03 setup: Apache with a vhost on 8081, content labeled default_t,
# port 8081 not labeled http_port_t, httpd stopped. Prints nothing on success.
set -eu

LAB=selinux-03
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"

if [ "$(getenforce)" = Disabled ]; then
	echo "Error: SELinux is disabled; this lab needs SELinux enabled." >&2
	exit 1
fi

# Remember what the system looked like before the lab, once, so that
# cleanup only removes what the lab installed. A second run keeps it.
if [ ! -r "$STATE_FILE" ]; then
	httpd_pkg=no
	was_enabled=no
	was_active=no
	rpm -q httpd >/dev/null 2>&1 && httpd_pkg=yes
	systemctl is-enabled --quiet httpd 2>/dev/null && was_enabled=yes
	systemctl is-active --quiet httpd 2>/dev/null && was_active=yes
	mkdir -p "$STATE_DIR"
	{
		echo "httpd_preinstalled=$httpd_pkg"
		echo "httpd_was_enabled=$was_enabled"
		echo "httpd_was_active=$was_active"
	} > "$STATE_FILE"
	chmod 644 "$STATE_FILE"
fi

if ! { rpm -q httpd >/dev/null 2>&1 && rpm -q policycoreutils-python-utils >/dev/null 2>&1; }; then
	dnf -y -q install httpd policycoreutils-python-utils >/dev/null
fi

# Reset what a previous run or the solution left behind
systemctl disable --now httpd >/dev/null 2>&1 || true
semodule -r myapp_custom >/dev/null 2>&1 || true
semanage port -d -t http_port_t -p tcp 8081 >/dev/null 2>&1 || true
semanage fcontext -l -C 2>/dev/null | awk '$1 ~ "^/webapp" { print $1 }' |
	while read -r p; do semanage fcontext -d "$p" >/dev/null 2>&1 || true; done
rm -rf /webapp
setenforce 1

# Content: labeled with the default type of the file system root
mkdir -p /webapp/porttest
echo "Custom port test page" > /webapp/porttest/index.html
chown -R apache:apache /webapp/porttest
restorecon -R /webapp

# Apache listens on 8081, which SELinux does not allow for httpd_t yet
cat > /etc/httpd/conf.d/lab-port.conf <<'CONF'
Listen 8081
<VirtualHost *:8081>
    DocumentRoot /webapp/porttest
    <Directory /webapp/porttest>
        Require all granted
    </Directory>
</VirtualHost>
CONF
