#!/bin/bash
# webserver-08 grader
source /opt/linux-labs/lib/grading.sh

LAB=webserver-08
STATE_FILE=/opt/linux-labs/state/$LAB
HTPASSWD=/etc/httpd/lab.htpasswd
ALICE_PW=redwood42
BOB_PW=seashell17
LOCAL=http://127.0.0.1

state_value() {
	sed -n "s/^$1=//p" "$STATE_FILE" 2>/dev/null | head -n 1
}

# The IPv4 address of the interface with the default route
dev=$(ip -4 route show default 2>/dev/null |
	awk '{ for (i = 1; i < NF; i++) if ($i == "dev") { print $(i + 1); exit } }')
addr=
[ -n "$dev" ] && addr=$(ip -4 -o addr show dev "$dev" 2>/dev/null |
	awk '{ split($4, a, "/"); print a[1]; exit }')

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# code_is <code> <url> [curl options...]: the response has this status
code_is() {
	local want=$1 url=$2 got
	shift 2
	got=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$@" "$url")
	[ "$got" = "$want" ]
}

# page_ok <marker> <url> [curl options...]: status 200 and the marker
page_ok() {
	local marker=$1 url=$2 got
	shift 2
	got=$(curl -s -o "$tmp/body" -w '%{http_code}' --max-time 10 "$@" "$url")
	[ "$got" = 200 ] && grep -qF "$marker" "$tmp/body"
}

enabled_running() {
	systemctl is-enabled --quiet httpd && systemctl is-active --quiet httpd
}

users_exact() {
	[ -f "$HTPASSWD" ] || return 1
	[ "$(grep -v '^[[:space:]]*$' "$HTPASSWD" | cut -d: -f1 | LC_ALL=C sort |
		tr '\n' ' ')" = "alice bob " ]
}

# Every entry has a hash, and neither password appears in the file
no_plaintext() {
	[ -f "$HTPASSWD" ] || return 1
	grep -qF -e "$ALICE_PW" -e "$BOB_PW" "$HTPASSWD" && return 1
	awk -F: 'NF && $0 !~ /^[[:space:]]*$/ {
			if ($2 !~ /^(\$(apr1|2[aby]|5|6)\$|\{SHA\})/) bad = 1
		}
		END { exit bad }' "$HTPASSWD"
}

not_world_readable() {
	local mode
	[ -f "$HTPASSWD" ] || return 1
	mode=$(stat -c %a "$HTPASSWD") || return 1
	[ $((8#$mode & 4)) -eq 0 ]
}

apache_reads() {
	[ -f "$HTPASSWD" ] && id apache >/dev/null 2>&1 || return 1
	runuser -u apache -- test -r "$HTPASSWD"
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

grade_begin webserver-08
grade_require_state webserver-08 "$STATE_FILE"

criterion "httpd is enabled and running" enabled_running
criterion "The Apache configuration test passes" apachectl configtest
criterion "$LOCAL/ returns the public page" page_ok PUBLIC-PAGE-OK "$LOCAL/"
criterion "/private/ answers 401 without credentials" code_is 401 "$LOCAL/private/"
criterion "/private/ answers 401 for alice with a wrong password" \
	code_is 401 "$LOCAL/private/" -u alice:wrong-password
criterion "/private/ returns the private page for alice" \
	page_ok PRIVATE-PAGE-OK "$LOCAL/private/" -u "alice:$ALICE_PW"
criterion "/private/ returns the private page for bob" \
	page_ok PRIVATE-PAGE-OK "$LOCAL/private/" -u "bob:$BOB_PW"
criterion "$HTPASSWD holds exactly alice and bob" users_exact
criterion "$HTPASSWD holds hashes, no plain text passwords" no_plaintext
criterion "$HTPASSWD is not readable by others" not_world_readable
criterion "The user apache can read $HTPASSWD" apache_reads
criterion "$LOCAL/admin/ returns the admin page" page_ok ADMIN-PAGE-OK "$LOCAL/admin/"
if [ -n "$addr" ]; then
	criterion "http://$addr/ returns the public page" page_ok PUBLIC-PAGE-OK "http://$addr/"
	criterion "http://$addr/admin/ answers 403" code_is 403 "http://$addr/admin/"
else
	criterion_result "The default route address gets the public page" 1
	criterion_result "The default route address gets 403 for /admin/" 1
fi
criterion "SELinux is in enforcing mode" selinux_enforcing
criterion "Service http is allowed in the default zone now" fw_runtime
criterion "Service http is allowed in the default zone permanently" fw_permanent
grade_end
