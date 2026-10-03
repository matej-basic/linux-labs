#!/bin/bash
# webserver-06 grader
source /opt/linux-labs/lib/grading.sh

LAB=webserver-06
STATE_FILE=/opt/linux-labs/state/$LAB
POOL=/etc/php-fpm.d/intranet.conf
SOCK=/run/php-fpm/intranet.sock
VHOST=/etc/httpd/conf.d/phpapp.conf
PUBLIC=/srv/phpapp/public

state_value() {
	sed -n "s/^$1=//p" "$STATE_FILE" 2>/dev/null | head -n 1
}

# conf_value <file> <section> <key>: the value of <key> in [<section>]
conf_value() {
	awk -v sect_want="[$2]" -v key="$3" '
		{ sub(/^[ \t]+/, ""); sub(/[ \t\r]+$/, "") }
		/^\[/ { sect = $0; next }
		sect != sect_want { next }
		/^[;#]/ { next }
		{
			i = index($0, "=")
			if (i == 0) next
			k = substr($0, 1, i - 1); v = substr($0, i + 1)
			gsub(/[ \t]/, "", k)
			sub(/^[ \t]+/, "", v)
			gsub(/^"|"$/, "", v)
			if (k == key) val = v
		}
		END { print val }
	' "$1" 2>/dev/null
}

pool_value() {
	conf_value "$POOL" intranet "$1"
}

pool_section() {
	grep -Eq '^[[:space:]]*\[intranet\][[:space:]]*$' "$POOL" 2>/dev/null
}

pool_user() {
	pool_section && [ "$(pool_value user)" = phpapp ]
}

pool_listen() {
	pool_section && [ "$(pool_value listen)" = "$SOCK" ]
}

pool_pm() {
	pool_section && [ "$(pool_value pm)" = ondemand ] &&
		[ "$(pool_value pm.max_children)" = 5 ]
}

pool_memory() {
	pool_section && [ "$(pool_value 'php_admin_value[memory_limit]')" = 64M ]
}

www_user() {
	[ "$(conf_value /etc/php-fpm.d/www.conf www user)" = apache ]
}

# The socket exists and other users have no write access to it
sock_exists() {
	test -S "$SOCK"
}

sock_not_world() {
	local mode
	test -S "$SOCK" || return 1
	mode=$(stat -c %a "$SOCK" 2>/dev/null) || return 1
	[ $((8#$mode & 2)) -eq 0 ]
}

both_enabled_running() {
	systemctl is-enabled --quiet "$1" && systemctl is-active --quiet "$1"
}

# fetch <url>: the body of a 200 response, or failure
fetch() {
	local out
	out=$(curl -s --max-time 10 -o - -w '\n%{http_code}' "$1" 2>/dev/null) || return 1
	[ "$(printf '%s\n' "$out" | tail -n 1)" = 200 ] || return 1
	printf '%s\n' "$out" | sed '$d'
}

# page_runs <url>: the page was run by PHP, not sent as source
page_runs() {
	local body
	body=$(fetch "$1") || return 1
	printf '%s\n' "$body" | grep -q '^effective_uid=' &&
		! printf '%s\n' "$body" | grep -qF '<?php'
}

page_uid() {
	local uid
	uid=$(id -u phpapp 2>/dev/null) || return 1
	fetch http://localhost/ | grep -qx "effective_uid=$uid"
}

page_memory() {
	fetch http://localhost/ | grep -qx 'memory_limit=64M'
}

# Everything in $PUBLIC has the type httpd_sys_content_t, and the
# file context rules of the policy give it that type
public_type_ok() {
	local p
	[ -d "$PUBLIC" ] || return 1
	while IFS= read -r p; do
		[ "$(stat -c %C "$p" 2>/dev/null | cut -d: -f3)" = httpd_sys_content_t ] ||
			return 1
	done < <(find "$PUBLIC" 2>/dev/null)
}

public_rules_ok() {
	local p
	[ -d "$PUBLIC" ] || return 1
	while IFS= read -r p; do
		[ "$(matchpathcon -n "$p" 2>/dev/null | cut -d: -f3)" = httpd_sys_content_t ] ||
			return 1
	done < <(find "$PUBLIC" 2>/dev/null)
}

selinux_enforcing() {
	[ "$(getenforce 2>/dev/null)" = Enforcing ]
}

fw_runtime() {
	firewall-cmd --zone="$(state_value zone)" --query-service=http
}

fw_permanent() {
	firewall-cmd --permanent --zone="$(state_value zone)" --query-service=http
}

# The IPv4 address of the interface with the default route
dev=$(ip -4 route show default 2>/dev/null |
	awk '{ for (i = 1; i < NF; i++) if ($i == "dev") { print $(i + 1); exit } }')
addr=
[ -n "$dev" ] && addr=$(ip -4 -o addr show dev "$dev" 2>/dev/null |
	awk '{ split($4, a, "/"); print a[1]; exit }')

grade_begin webserver-06
grade_require_state webserver-06 "$STATE_FILE"

criterion "httpd is enabled and running" both_enabled_running httpd
criterion "php-fpm is enabled and running" both_enabled_running php-fpm
criterion "The Apache configuration test passes" httpd -t
criterion "The PHP-FPM configuration test passes" php-fpm -t
criterion "Pool intranet in $POOL runs as phpapp" pool_user
criterion "Pool intranet listens on $SOCK" pool_listen
criterion "Pool intranet uses pm ondemand with 5 children at most" pool_pm
criterion "Pool intranet sets the admin value memory_limit 64M" pool_memory
criterion "Pool www in /etc/php-fpm.d/www.conf still runs as apache" www_user
criterion "Socket $SOCK exists" sock_exists
criterion "Other users cannot write to the socket" sock_not_world
criterion "File $VHOST exists" test -f "$VHOST"
criterion "http://localhost/ runs index.php" page_runs http://localhost/
criterion "index.php runs as user phpapp" page_uid
criterion "index.php runs with memory_limit 64M" page_memory
if [ -n "$addr" ]; then
	criterion "http://$addr/ runs index.php" page_runs "http://$addr/"
else
	criterion_result "The address of $(hostname -s) runs index.php" 1
fi
criterion "Everything in $PUBLIC has type httpd_sys_content_t" public_type_ok
criterion "The file context rules give $PUBLIC this type" public_rules_ok
criterion "SELinux is in enforcing mode" selinux_enforcing
criterion "Service http is allowed in the default zone now" fw_runtime
criterion "Service http is allowed in the default zone permanently" fw_permanent
grade_end
