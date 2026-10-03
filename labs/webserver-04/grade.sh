#!/bin/bash
# webserver-04 grader
source /opt/linux-labs/lib/grading.sh

LAB=webserver-04
HOST=app.lab.local
STATE_FILE=/opt/linux-labs/state/$LAB
CRT=/etc/pki/tls/certs/app.lab.local.crt
KEY=/etc/pki/tls/private/app.lab.local.key
SEL=/var/lib/selinux/targeted/active

state_value() {
	sed -n "s/^$1=//p" "$STATE_FILE" 2>/dev/null | head -n 1
}

# curl to nginx on this machine with the lab host name
lcurl() {
	curl -s --max-time 10 --resolve "$HOST:80:127.0.0.1" \
		--resolve "$HOST:443:127.0.0.1" "$@"
}

nginx_config_valid() {
	nginx -t
}

cert_names_host() {
	local subj
	[ -f "$CRT" ] || return 1
	subj=$(openssl x509 -in "$CRT" -noout -subject -nameopt RFC2253 2>/dev/null) || return 1
	subj=${subj#subject=}
	[[ ",$subj," == *",CN=$HOST,"* ]] && return 0
	openssl x509 -in "$CRT" -noout -text 2>/dev/null |
		grep -Eq "DNS:$HOST(,|[[:space:]]|$)"
}

key_protected() {
	[ -f "$KEY" ] || return 1
	[ "$(stat -c '%U %a' "$KEY")" = "root 600" ]
}

https_serves_app() {
	lcurl -k "https://$HOST/" | grep -q 'webapp backend is up'
}

https_uses_cert() {
	local served file
	[ -f "$CRT" ] || return 1
	served=$(openssl s_client -connect 127.0.0.1:443 -servername "$HOST" \
		</dev/null 2>/dev/null | openssl x509 -noout -fingerprint -sha256 2>/dev/null) || return 1
	file=$(openssl x509 -in "$CRT" -noout -fingerprint -sha256) || return 1
	[ -n "$served" ] && [ "$served" = "$file" ]
}

http_redirects() {
	local out
	out=$(lcurl -o /dev/null -w '%{http_code} %{redirect_url}' \
		"http://$HOST/headers?x=1") || return 1
	[ "$out" = "301 https://$HOST/headers?x=1" ]
}

# The headers the backend received through the proxy
backend_header() {
	lcurl -k "https://$HOST/headers" |
		tr -d '\r' | awk -v h="$1" '
		BEGIN { h = tolower(h) }
		{ n = index($0, ":"); if (n == 0) next
		  k = tolower(substr($0, 1, n - 1)); v = substr($0, n + 1)
		  sub(/^[[:space:]]+/, "", v)
		  if (k == h) print v }'
}

forwarded_proto() {
	[ "$(backend_header X-Forwarded-Proto)" = https ]
}

forwarded_for() {
	backend_header X-Forwarded-For | grep -Eq '(^|[[:space:],])127\.0\.0\.1([[:space:],]|$)'
}

# nginx may connect to port 8081 also after a reboot: the boolean is on
# in the policy store. Labelling port 8081 http_port_t is not enough
# with the default booleans of Rocky 8 and 9 (nginx still gets 502).
selinux_persistent() {
	grep -qx 'httpd_can_network_connect=1' "$SEL/booleans.local" 2>/dev/null
}

fw_open() {
	local perm=$1 zone s p
	zone=$(state_value zone)
	[ -n "$zone" ] || return 1
	for s in http:80 https:443; do
		p=${s#*:}
		s=${s%%:*}
		# shellcheck disable=SC2086 # $perm is empty or one option
		firewall-cmd $perm --zone="$zone" --query-service="$s" ||
			firewall-cmd $perm --zone="$zone" --query-port="$p/tcp" || return 1
	done
}

grade_begin webserver-04
grade_require_state webserver-04 "$STATE_FILE"

criterion "nginx is enabled" systemctl is-enabled --quiet nginx
criterion "nginx is running" systemctl is-active --quiet nginx
criterion "nginx configuration test passes" nginx_config_valid
criterion "Certificate app.lab.local.crt names $HOST" cert_names_host
criterion "Key app.lab.local.key is owned by root, mode 0600" key_protected
criterion "https://$HOST/ returns the backend page" https_serves_app
criterion "https://$HOST/ presents app.lab.local.crt" https_uses_cert
criterion "http://$HOST/ redirects with 301 to https, same path" http_redirects
criterion "Backend receives X-Forwarded-Proto: https" forwarded_proto
criterion "Backend receives X-Forwarded-For with the client address" forwarded_for
criterion "SELinux is enforcing" test "$(getenforce 2>/dev/null)" = Enforcing
criterion "SELinux boolean for nginx connections is on persistently" selinux_persistent
criterion "Services http and https are open in the firewall now" fw_open ""
criterion "Services http and https are open permanently" fw_open --permanent
grade_end
