#!/bin/bash
# webserver-06 setup: a PHP application in /srv/phpapp/public that runs
# as the system user phpapp, without a web server. Setup creates the
# user phpapp (home /srv/phpapp, no login shell) and the page
# /srv/phpapp/public/index.php. The tree has no SELinux file context
# rule, so it is labelled var_t. The student installs httpd and php-fpm.
# Prints nothing on success.
#
# The first run records the package set (pkg_snapshot), the firewall
# state of http and 80/tcp in the default zone, the service state of
# httpd and php-fpm, the SELinux runtime mode and the local file context
# rules for /srv/phpapp. cleanup.sh puts all of it back.
set -eu
source /opt/linux-labs/lib/packages.sh

LAB=webserver-06
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
APP=/srv/phpapp
POOL=/etc/php-fpm.d/intranet.conf
VHOST=/etc/httpd/conf.d/phpapp.conf
FC_LOCAL=/etc/selinux/targeted/contexts/files/file_contexts.local

if ! command -v getenforce >/dev/null 2>&1 || [ "$(getenforce)" = Disabled ]; then
	echo "Error: SELinux is disabled; this lab needs SELinux enabled." >&2
	exit 1
fi
if ! command -v firewall-cmd >/dev/null 2>&1 \
	|| ! systemctl is-active --quiet firewalld 2>/dev/null; then
	echo "Error: firewalld is not running on this machine." >&2
	exit 1
fi

pkg_snapshot "$LAB"

state_value() {
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}

# Local file context rules for /srv/phpapp, one path per line
fc_rules() {
	[ -r "$FC_LOCAL" ] || return 0
	awk '$1 ~ /^\/srv\/phpapp/ { print $1 }' "$FC_LOCAL"
}

# First run only: what the machine looked like before the lab
if [ ! -r "$STATE_FILE" ]; then
	mkdir -p "$STATE_DIR"
	zone=$(firewall-cmd --get-default-zone)
	fw_open=
	firewall-cmd --permanent --zone="$zone" --query-service=http >/dev/null 2>&1 \
		&& fw_open="$fw_open p:service:http"
	firewall-cmd --zone="$zone" --query-service=http >/dev/null 2>&1 \
		&& fw_open="$fw_open r:service:http"
	firewall-cmd --permanent --zone="$zone" --query-port=80/tcp >/dev/null 2>&1 \
		&& fw_open="$fw_open p:port:80/tcp"
	firewall-cmd --zone="$zone" --query-port=80/tcp >/dev/null 2>&1 \
		&& fw_open="$fw_open r:port:80/tcp"
	svc_state=
	for s in httpd php-fpm; do
		systemctl is-enabled --quiet "$s" 2>/dev/null && svc_state="$svc_state $s:enabled"
		systemctl is-active --quiet "$s" 2>/dev/null && svc_state="$svc_state $s:active"
	done
	tmp="$STATE_FILE.tmp"
	{
		echo "zone=$zone"
		echo "fw_open=$fw_open"
		echo "services=$svc_state"
		echo "selinux_mode=$(getenforce)"
		echo "fc_rules=$(fc_rules | tr '\n' ' ')"
	} > "$tmp"
	chmod 0644 "$tmp"
	mv "$tmp" "$STATE_FILE"
fi

# Reset what a previous run or the solution left behind
systemctl disable --now httpd php-fpm >/dev/null 2>&1 || true
systemctl reset-failed httpd php-fpm >/dev/null 2>&1 || true
rm -f "$POOL" "$VHOST"
rm -rf "$APP"
if command -v semanage >/dev/null 2>&1; then
	before=" $(state_value fc_rules) "
	for p in $(fc_rules); do
		case "$before" in
		*" $p "*) ;;
		*) semanage fcontext -d "$p" >/dev/null 2>&1 || true ;;
		esac
	done
fi
setenforce 1

if [ -n "$(ss -H -tln 'sport = :80' 2>/dev/null)" ]; then
	echo "Error: another service already listens on TCP port 80." >&2
	exit 1
fi

# The application account: a system user without a login shell
if ! id phpapp >/dev/null 2>&1; then
	useradd -r -d "$APP" -M -s /sbin/nologin -c 'PHP intranet application' phpapp
fi

mkdir -m 0755 "$APP" "$APP/public"
cat > "$APP/public/index.php" <<'PHP'
<?php
// Intranet status page: which account runs this script, and with
// which memory limit.
$uid = 'unknown';
foreach (file('/proc/self/status') as $line) {
    if (strncmp($line, 'Uid:', 4) == 0) {
        $fields = preg_split('/\s+/', trim($line));
        $uid = $fields[2];
    }
}
header('Content-Type: text/plain');
echo "Intranet application\n";
echo "effective_uid=" . $uid . "\n";
echo "memory_limit=" . ini_get('memory_limit') . "\n";
PHP
chmod 0644 "$APP/public/index.php"
chown -R phpapp:phpapp "$APP"
restorecon -R "$APP"

# The firewall: no http and no 80/tcp in the default zone
zone=$(state_value zone)
for s in service:http port:80/tcp; do
	kind=${s%%:*}
	val=${s#*:}
	firewall-cmd --permanent --zone="$zone" "--remove-$kind=$val" >/dev/null 2>&1 || true
	firewall-cmd --zone="$zone" "--remove-$kind=$val" >/dev/null 2>&1 || true
done
exit 0
