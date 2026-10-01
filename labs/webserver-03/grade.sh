#!/bin/bash
# webserver-03 grader
source /opt/linux-labs/lib/grading.sh

HOST=lab3.local
ROOT=/var/www/lab3/html
CRT=/etc/pki/tls/certs/lab3.crt
KEY=/etc/pki/tls/private/lab3.key
CONF=/etc/httpd/conf.d/lab3.conf

hosts_entry() {
	getent hosts "$HOST" | awk '{ print $1 }' | grep -qx '127\.0\.0\.1'
}

index_content() {
	[ -f "$ROOT/index.html" ] && grep -q 'Lab 3 HTTPS' "$ROOT/index.html"
}

cert_self_signed_cn() {
	local subj iss
	[ -f "$CRT" ] || return 1
	subj=$(openssl x509 -in "$CRT" -noout -subject -nameopt RFC2253) || return 1
	iss=$(openssl x509 -in "$CRT" -noout -issuer -nameopt RFC2253) || return 1
	subj=${subj#subject=}
	[ "$subj" = "${iss#issuer=}" ] || return 1
	[[ ",$subj," == *",CN=$HOST,"* ]]
}

key_matches_cert() {
	local a b
	[ -f "$KEY" ] && [ -f "$CRT" ] || return 1
	a=$(openssl x509 -in "$CRT" -noout -pubkey 2>/dev/null) || return 1
	b=$(openssl pkey -in "$KEY" -pubout 2>/dev/null) || return 1
	[ -n "$a" ] && [ "$a" = "$b" ]
}

config_valid() {
	[ -f "$CONF" ] && httpd -t
}

listens_443() {
	ss -H -tln | awk '{ print $4 }' | grep -Eq ':443$'
}

http_redirects() {
	local out
	out=$(curl -s -o /dev/null --max-time 10 --resolve "$HOST:80:127.0.0.1" \
		-w '%{http_code} %{redirect_url}' "http://$HOST/") || return 1
	[ "$out" = "301 https://$HOST/" ]
}

https_serves_page() {
	curl -sk --max-time 10 --resolve "$HOST:443:127.0.0.1" \
		"https://$HOST/" | grep -q 'Lab 3 HTTPS'
}

https_uses_cert() {
	local served file
	[ -f "$CRT" ] || return 1
	served=$(openssl s_client -connect 127.0.0.1:443 -servername "$HOST" \
		</dev/null 2>/dev/null | openssl x509 -noout -fingerprint -sha256) || return 1
	file=$(openssl x509 -in "$CRT" -noout -fingerprint -sha256) || return 1
	[ -n "$served" ] && [ "$served" = "$file" ]
}

grade_begin webserver-03
criterion "Package httpd is installed" rpm -q httpd
criterion "Package mod_ssl is installed" rpm -q mod_ssl
criterion "httpd is running" systemctl is-active --quiet httpd
criterion "$HOST resolves to 127.0.0.1" hosts_entry
criterion "Document root $ROOT exists" test -d "$ROOT"
criterion "index.html contains 'Lab 3 HTTPS'" index_content
criterion "Certificate $CRT is self-signed for $HOST" cert_self_signed_cn
criterion "Private key $KEY matches the certificate" key_matches_cert
criterion "Virtual host file $CONF exists" test -f "$CONF"
criterion "Apache configuration is valid" config_valid
criterion "httpd listens on port 443" listens_443
criterion "http://$HOST/ redirects permanently to HTTPS" http_redirects
criterion "https://$HOST/ serves the page" https_serves_page
criterion "https://$HOST/ presents the lab certificate" https_uses_cert
grade_end
