#!/bin/bash
# dns-03 grader. Runs as the student, who cannot read /etc/named.conf or
# /var/named, so everything is checked through named on 127.0.0.1.
source /opt/linux-labs/lib/grading.sh

ZONE=labsecure.com
SERVER=127.0.0.1

# dig against the local named, answer section only
q() {
	dig +noall +answer +time=3 +tries=2 "@$SERVER" "$@" 2>/dev/null
}

# First global IPv4 address of this host (not 127.0.0.1)
other_address() {
	ip -4 -o addr show scope global 2>/dev/null |
		awk '{ split($4, a, "/"); print a[1]; exit }'
}

has_a_record() {
	q "$1.$ZONE" A | awk -v v="$2" '$4 == "A" && $5 == v { f = 1 } END { exit !f }'
}

has_ns_record() {
	q "$ZONE" NS | awk '$4 == "NS" && tolower($5) == "ns1.labsecure.com." { f = 1 } END { exit !f }'
}

zone_is_authoritative() {
	dig +noall +comments +norec +time=3 +tries=2 "@$SERVER" "$ZONE" SOA 2>/dev/null |
		grep -Eq '^;; flags:.* aa[ ;]'
}

# KSK has flag 257, ZSK flag 256; both must use a SHA-2 or newer algorithm
has_key() {
	q "$ZONE" DNSKEY | awk -v f="$1" \
		'$4 == "DNSKEY" && $5 == f && $6 == 3 && $7 ~ /^(8|10|13|14|15|16)$/ { k = 1 } END { exit !k }'
}

answers_are_signed() {
	q +dnssec "web.$ZONE" A | awk '$4 == "RRSIG" && $5 == "A" { a = 1 } END { exit !a }' || return 1
	q +dnssec "$ZONE" DNSKEY | awk '$4 == "RRSIG" && $5 == "DNSKEY" { k = 1 } END { exit !k }'
}

axfr_local_signed() {
	local out
	out=$(dig +noall +answer +time=5 +tries=1 "@$SERVER" "$ZONE" AXFR 2>/dev/null) || return 1
	echo "$out" | awk '$4 == "SOA" { s = 1 } $4 == "RRSIG" { r = 1 } END { exit !(s && r) }'
}

# named must answer from the other address (not vacuous), but refuse AXFR
axfr_other_refused() {
	local ip out
	ip=$(other_address)
	[ -n "$ip" ] || return 1
	dig +noall +answer +time=3 +tries=2 -b "$ip" "@$SERVER" "$ZONE" SOA 2>/dev/null |
		awk '$4 == "SOA" { s = 1 } END { exit !s }' || return 1
	out=$(dig +noall +answer +time=5 +tries=1 -b "$ip" "@$SERVER" "$ZONE" AXFR 2>/dev/null) || true
	! echo "$out" | awk '$4 == "SOA" { s = 1 } END { exit !s }'
}

named_enabled_and_running() {
	systemctl is-active --quiet named && systemctl is-enabled --quiet named
}

grade_begin dns-03

criterion "Packages bind and bind-utils are installed" rpm -q bind bind-utils
criterion "named is enabled and running" named_enabled_and_running
criterion "Server is authoritative for $ZONE" zone_is_authoritative
criterion "Zone has the NS record ns1.$ZONE" has_ns_record
criterion "ns1.$ZONE has address 192.168.1.5" has_a_record ns1 192.168.1.5
criterion "web.$ZONE has address 192.168.1.10" has_a_record web 192.168.1.10
criterion "api.$ZONE has address 192.168.1.15" has_a_record api 192.168.1.15
criterion "Zone publishes a KSK using a SHA-2 algorithm" has_key 257
criterion "Zone publishes a ZSK using a SHA-2 algorithm" has_key 256
criterion "Zone answers carry RRSIG records" answers_are_signed
criterion "AXFR from 127.0.0.1 returns the signed zone" axfr_local_signed
criterion "AXFR from another address of this host is refused" axfr_other_refused
grade_end
