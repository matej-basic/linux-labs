#!/bin/bash
# webserver-02 grader
source /opt/linux-labs/lib/grading.sh

DOCROOT=/var/www/lab2/html
NAME=lab2.local
STATE_FILE=/opt/linux-labs/state/webserver-02

grade_begin webserver-02
grade_require_state webserver-02 "$STATE_FILE"

httpd_enabled_running() {
	systemctl is-enabled --quiet httpd && systemctl is-active --quiet httpd
}

index_has_text() {
	grep -qF "Welcome to Lab 2" "$DOCROOT/index.html"
}

hosts_maps_name() {
	awk -v n="$NAME" '
		{ sub(/#.*/, "") }
		$1 == "127.0.0.1" { for (i = 2; i <= NF; i++) if ($i == n) found = 1 }
		END { exit !found }' /etc/hosts
}

# The running Apache has a name-based vhost for the name, whose
# DocumentRoot (read from its configuration block) is the lab directory
vhost_docroot() {
	local entry file line
	entry=$(httpd -S 2>&1 | grep -E "[[:space:]]$NAME \(/" | head -n 1)
	[ -n "$entry" ] || return 1
	entry=${entry##*(}
	entry=${entry%)*}
	file=${entry%:*}
	line=${entry##*:}
	[ -r "$file" ] || return 1
	sed -n "${line},/<\/VirtualHost>/p" "$file" |
		grep -Eiq '^[[:space:]]*DocumentRoot[[:space:]]+"?/var/www/lab2/html/?"?[[:space:]]*$'
}

served_page_matches() {
	local body
	body=$(curl -fsS --max-time 10 "http://$NAME/") || return 1
	[ -n "$body" ] && [ "$body" = "$(cat "$DOCROOT/index.html")" ]
}

criterion "Package httpd is installed" rpm -q httpd
criterion "httpd is enabled and running" httpd_enabled_running
criterion "Directory $DOCROOT exists" test -d "$DOCROOT"
criterion "index.html contains 'Welcome to Lab 2'" index_has_text
criterion "$NAME resolves to 127.0.0.1 in /etc/hosts" hosts_maps_name
criterion "Apache configuration passes the syntax check" httpd -t
criterion "Virtual host $NAME uses DocumentRoot $DOCROOT" vhost_docroot
criterion "http://$NAME/ returns index.html with status 200" served_page_matches
grade_end
