#!/bin/bash
# webserver-07 grader
source /opt/linux-labs/lib/grading.sh

LAB=webserver-07
STATE_FILE=/opt/linux-labs/state/$LAB
HOST=intranet.lab.example
CA_CRT=/srv/lab-ca/ca.crt
CRT=/etc/pki/tls/certs/intranet.lab.example.crt
KEY=/etc/pki/tls/private/intranet.lab.example.key
VHOST=/etc/httpd/conf.d/intranet.conf
SITE=/srv/intranet
ANCHORS=/etc/pki/ca-trust/source/anchors
BUNDLE=/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem
MARKER=INTRANET-LAB-EXAMPLE-OK

state_value() {
	sed -n "s/^$1=//p" "$STATE_FILE" 2>/dev/null | head -n 1
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
SERVED="$tmp/served.pem"

# The certificate httpd presents for the lab host name, in PEM
timeout 15 openssl s_client -connect 127.0.0.1:443 -servername "$HOST" </dev/null 2>/dev/null |
	openssl x509 -out "$SERVED" 2>/dev/null || rm -f "$SERVED"

installed() {
	rpm -q httpd && rpm -q mod_ssl
}

enabled_running() {
	systemctl is-enabled --quiet httpd && systemctl is-active --quiet httpd
}

served_is_file() {
	local a b
	[ -s "$SERVED" ] && [ -f "$CRT" ] || return 1
	a=$(openssl x509 -in "$SERVED" -noout -fingerprint -sha256) || return 1
	b=$(openssl x509 -in "$CRT" -noout -fingerprint -sha256) || return 1
	[ -n "$a" ] && [ "$a" = "$b" ]
}

# Signed by the lab CA: the signature verifies with the CA certificate
# alone, without the system trust store
served_verifies() {
	[ -s "$SERVED" ] && [ -f "$CA_CRT" ] || return 1
	openssl verify -no-CApath -CAfile "$CA_CRT" "$SERVED"
}

served_san() {
	[ -s "$SERVED" ] || return 1
	openssl x509 -in "$SERVED" -noout -text |
		grep -A1 'X509v3 Subject Alternative Name' |
		grep -Eq "DNS:$HOST(,|[[:space:]]|$)"
}

served_valid_300() {
	[ -s "$SERVED" ] || return 1
	openssl x509 -in "$SERVED" -noout -checkend $((300 * 86400))
}

served_rsa_2048() {
	local text bits
	[ -s "$SERVED" ] || return 1
	text=$(openssl x509 -in "$SERVED" -noout -text) || return 1
	printf '%s\n' "$text" | grep -q 'Public Key Algorithm: rsaEncryption' || return 1
	bits=$(printf '%s\n' "$text" | sed -n 's/.*Public-Key: (\([0-9]*\) bit.*/\1/p' | head -n 1)
	[ -n "$bits" ] && [ "$bits" -ge 2048 ]
}

key_matches() {
	local a b
	[ -f "$KEY" ] && [ -f "$CRT" ] || return 1
	a=$(openssl x509 -in "$CRT" -noout -pubkey 2>/dev/null) || return 1
	b=$(openssl pkey -in "$KEY" -pubout 2>/dev/null) || return 1
	[ -n "$a" ] && [ "$a" = "$b" ]
}

key_protected() {
	[ -f "$KEY" ] || return 1
	[ "$(stat -c '%U %a' "$KEY")" = "root 600" ]
}

# The PEM body of a certificate on one line
pem_line() {
	sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' "$1" |
		sed '/-----/d' | tr -d '\n\r '
}

ca_in_anchors() {
	local want f fp
	[ -f "$CA_CRT" ] || return 1
	want=$(openssl x509 -in "$CA_CRT" -noout -fingerprint -sha256) || return 1
	for f in "$ANCHORS"/*; do
		[ -f "$f" ] || continue
		fp=$(openssl x509 -in "$f" -noout -fingerprint -sha256 2>/dev/null) || continue
		[ "$fp" = "$want" ] && return 0
	done
	return 1
}

ca_in_bundle() {
	local want
	[ -f "$CA_CRT" ] && [ -f "$BUNDLE" ] || return 1
	want=$(pem_line "$CA_CRT")
	[ -n "$want" ] || return 1
	awk '/-----BEGIN CERTIFICATE-----/ { c = ""; next }
		/-----END CERTIFICATE-----/ { print c; next }
		{ gsub(/[ \r]/, ""); c = c $0 }' "$BUNDLE" | grep -qxF "$want"
}

# The IPv4 address of the interface with the default route
dev=$(ip -4 route show default 2>/dev/null |
	awk '{ for (i = 1; i < NF; i++) if ($i == "dev") { print $(i + 1); exit } }')
addr=
[ -n "$dev" ] && addr=$(ip -4 -o addr show dev "$dev" 2>/dev/null |
	awk '{ split($4, a, "/"); print a[1]; exit }')

hosts_entry() {
	[ -n "$addr" ] || return 1
	awk -v a="$addr" -v h="$HOST" '
		{ sub(/#.*/, "") }
		$1 == a { for (i = 2; i <= NF; i++) if ($i == h) found = 1 }
		END { exit !found }' /etc/hosts || return 1
	[ "$(getent ahostsv4 "$HOST" | awk '{ print $1; exit }')" = "$addr" ]
}

trusted_curl() {
	curl -s --max-time 10 "https://$HOST/" | grep -qF "$MARKER"
}

selinux_enforcing() {
	[ "$(getenforce 2>/dev/null)" = Enforcing ]
}

# Everything in $SITE has the type httpd_sys_content_t, and the file
# context rules of the policy give it that type
site_type_ok() {
	local p
	[ -d "$SITE" ] || return 1
	while IFS= read -r p; do
		[ "$(stat -c %C "$p" 2>/dev/null | cut -d: -f3)" = httpd_sys_content_t ] ||
			return 1
	done < <(find "$SITE" 2>/dev/null)
}

site_rules_ok() {
	local p
	[ -d "$SITE" ] || return 1
	while IFS= read -r p; do
		[ "$(matchpathcon -n "$p" 2>/dev/null | cut -d: -f3)" = httpd_sys_content_t ] ||
			return 1
	done < <(find "$SITE" 2>/dev/null)
}

fw_runtime() {
	firewall-cmd --zone="$(state_value zone)" --query-service=https
}

fw_permanent() {
	firewall-cmd --permanent --zone="$(state_value zone)" --query-service=https
}

grade_begin webserver-07
grade_require_state webserver-07 "$STATE_FILE"

criterion "Packages httpd and mod_ssl are installed" installed
criterion "httpd is enabled and running" enabled_running
criterion "The Apache configuration test passes" apachectl configtest
criterion "File $VHOST exists" test -f "$VHOST"
criterion "Port 443 presents intranet.lab.example.crt" served_is_file
criterion "The certificate is signed by the lab CA" served_verifies
criterion "The certificate lists DNS:$HOST as a SAN" served_san
criterion "The certificate is valid for at least 300 more days" served_valid_300
criterion "The certificate has an RSA key of at least 2048 bits" served_rsa_2048
criterion "intranet.lab.example.key matches the certificate" key_matches
criterion "intranet.lab.example.key is owned by root, mode 0600" key_protected
criterion "The lab CA certificate is in $ANCHORS" ca_in_anchors
criterion "The lab CA is in the extracted system trust bundle" ca_in_bundle
if [ -n "$addr" ]; then
	criterion "$HOST resolves to $addr through /etc/hosts" hosts_entry
else
	criterion_result "$HOST resolves to the address of $(hostname -s)" 1
fi
criterion "curl trusts https://$HOST/ and gets the page" trusted_curl
criterion "Everything in $SITE has type httpd_sys_content_t" site_type_ok
criterion "The file context rules give $SITE this type" site_rules_ok
criterion "SELinux is in enforcing mode" selinux_enforcing
criterion "Service https is allowed in the default zone now" fw_runtime
criterion "Service https is allowed in the default zone permanently" fw_permanent
grade_end
