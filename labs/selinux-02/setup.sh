#!/bin/bash
# selinux-02 setup: creates /webapp with default (unlabelled) SELinux
# contexts and puts SELinux in enforcing mode. Prints nothing on success.
set -eu

STATE_FILE=/opt/linux-labs/state/selinux-02
MARKER='selinux-02 web application'

if ! command -v getenforce >/dev/null 2>&1 || [ "$(getenforce)" = Disabled ]; then
	echo "selinux-02: SELinux is disabled on this system, the lab cannot start." >&2
	exit 1
fi

# semanage is needed by the solution and by cleanup
if ! command -v semanage >/dev/null 2>&1; then
	dnf -y -q install policycoreutils-python-utils >/dev/null 2>&1 || {
		echo "selinux-02: cannot install policycoreutils-python-utils (semanage)." >&2
		exit 1
	}
fi

# Remember whether httpd was already installed, so cleanup does not
# remove a package the lab did not install. Keep the first answer when
# setup runs twice.
if [ -r "$STATE_FILE" ]; then
	preinstalled=$(sed -n 's/^httpd_preinstalled=//p' "$STATE_FILE")
else
	preinstalled=no
	rpm -q httpd >/dev/null 2>&1 && preinstalled=yes
fi

# Remove leftovers of an earlier run or of the solution
rm -f /etc/httpd/conf.d/myapp.conf
while read -r path; do
	[ -n "$path" ] && semanage fcontext -d "$path" >/dev/null 2>&1 || true
done < <(semanage fcontext -l -C 2>/dev/null | awk '$1 ~ /^\/webapp/ { print $1 }')
if rpm -q httpd >/dev/null 2>&1 && systemctl is-active --quiet httpd; then
	systemctl restart httpd >/dev/null 2>&1 || true
fi

# Content with default labels (default_t): httpd is denied access
rm -rf /webapp
mkdir -p /webapp/www /webapp/config /webapp/data
cat > /webapp/www/index.html <<HTML
<!DOCTYPE html>
<html><body><h1>MyApp</h1><p>$MARKER</p></body></html>
HTML
echo "db_host=localhost" > /webapp/config/db.conf
echo "application started" > /webapp/data/app.log
chmod -R a+rX /webapp
restorecon -R /webapp

# SELinux enforcing, now and after a reboot
setenforce 1
sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config

mkdir -p "$(dirname "$STATE_FILE")"
echo "httpd_preinstalled=$preinstalled" > "$STATE_FILE"
chmod 644 "$STATE_FILE"
