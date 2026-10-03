#!/bin/bash
# webserver-05 grader
source /opt/linux-labs/lib/grading.sh

LAB=webserver-05
STATE_FILE=/opt/linux-labs/state/$LAB
SITE=/srv/intranet
PAGE=$SITE/index.html
VHOST=/etc/httpd/conf.d/intranet.conf
MARKER='Welcome to the lab intranet'

state_value() {
	sed -n "s/^$1=//p" "$STATE_FILE" 2>/dev/null | head -n 1
}

# page_served <url>: status 200 and the marker in the body
page_served() {
	local out
	out=$(curl -s --max-time 10 -o - -w '\n%{http_code}' "$1" 2>/dev/null) || return 1
	[ "$(printf '%s\n' "$out" | tail -n 1)" = 200 ] &&
		printf '%s\n' "$out" | grep -qF "$MARKER"
}

# file_unchanged <path> <key>: the checksum setup.sh recorded
file_unchanged() {
	local want
	want=$(state_value "$2")
	[ -n "$want" ] && [ -f "$1" ] &&
		[ "$(sha256sum "$1" 2>/dev/null | awk '{ print $1 }')" = "$want" ]
}

httpd_enabled_running() {
	systemctl is-enabled --quiet httpd && systemctl is-active --quiet httpd
}

# Every path in the site has the type httpd_sys_content_t
site_type_ok() {
	local p
	[ -d "$SITE" ] || return 1
	while IFS= read -r p; do
		[ "$(stat -c %C "$p" 2>/dev/null | cut -d: -f3)" = httpd_sys_content_t ] ||
			return 1
	done < <(find "$SITE" 2>/dev/null)
}

# The policy file context rules give every path the type it has
site_rules_ok() {
	local p want
	[ -d "$SITE" ] || return 1
	while IFS= read -r p; do
		want=$(matchpathcon -n "$p" 2>/dev/null | cut -d: -f3)
		[ -n "$want" ] &&
			[ "$(stat -c %C "$p" 2>/dev/null | cut -d: -f3)" = "$want" ] ||
			return 1
	done < <(find "$SITE" 2>/dev/null)
}

site_not_writable() {
	[ -d "$SITE" ] || return 1
	[ -z "$(find "$SITE" -perm /022 -print -quit 2>/dev/null)" ]
}

apache_can_read() {
	runuser -u apache -- test -r "$PAGE"
}

fw_runtime() {
	firewall-cmd --zone="$(state_value zone)" --query-service=http
}

fw_permanent() {
	firewall-cmd --permanent --zone="$(state_value zone)" --query-service=http
}

selinux_enforcing() {
	[ "$(getenforce 2>/dev/null)" = Enforcing ] &&
		grep -Eq '^SELINUX=enforcing[[:space:]]*$' /etc/selinux/config
}

# Modules that are loaded now and were not loaded at the first start
new_modules() {
	local before m
	before=$(state_value modules)
	for m in $(semodule -l 2>/dev/null | awk '{ print $1 }'); do
		case " $before " in
		*" $m "*) ;;
		*) echo "$m" ;;
		esac
	done
}

# httpd_t is not permissive, and no permissive domain module is new
no_permissive_added() {
	! semanage permissive -l 2>/dev/null | grep -qw httpd_t || return 1
	! new_modules | grep -q '^permissive_'
}

# Other new modules (audit2allow and the like)
no_modules_added() {
	! new_modules | grep -vq '^permissive_'
}

# The IPv4 address of the interface with the default route
dev=$(ip -4 route show default 2>/dev/null |
	awk '{ for (i = 1; i < NF; i++) if ($i == "dev") { print $(i + 1); exit } }')
addr=
[ -n "$dev" ] && addr=$(ip -4 -o addr show dev "$dev" 2>/dev/null |
	awk '{ split($4, a, "/"); print a[1]; exit }')

grade_begin webserver-05
grade_require_state webserver-05 "$STATE_FILE"

criterion "httpd is enabled and running" httpd_enabled_running
criterion "The Apache configuration test passes" httpd -t
criterion "http://localhost/ returns the intranet page" \
	page_served http://localhost/
if [ -n "$addr" ]; then
	criterion "http://$addr/ returns the intranet page" \
		page_served "http://$addr/"
else
	criterion_result "The address of $(hostname -s) returns the intranet page" 1
fi
criterion "$PAGE is unchanged" file_unchanged "$PAGE" sum_page
criterion "$VHOST is unchanged" file_unchanged "$VHOST" sum_vhost
criterion "Everything in $SITE has type httpd_sys_content_t" site_type_ok
criterion "The file context rules give $SITE this type" site_rules_ok
criterion "User apache can read $PAGE" apache_can_read
criterion "Nothing in $SITE is group or world writable" site_not_writable
criterion "Service http is allowed in the default zone now" fw_runtime
criterion "Service http is allowed in the default zone permanently" fw_permanent
criterion "SELinux is enforcing now and in /etc/selinux/config" selinux_enforcing
criterion "No permissive domains were added" no_permissive_added
criterion "No policy modules were added" no_modules_added
grade_end
