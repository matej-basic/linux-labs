#!/bin/bash
# dns-02 grader
source /opt/linux-labs/lib/grading.sh

SERVER=127.0.0.1

# Query the local named without recursion (so only a loaded zone can
# answer) and print the short answer. Retries while named starts up.
q() {
	local out
	systemctl is-active --quiet named || return 1
	for _ in 1 2 3 4 5; do
		if out=$(cd /tmp && dig @"$SERVER" +norecurse +tries=1 +time=2 +short "$@" 2>/dev/null); then
			[ -n "$out" ] || return 1
			printf '%s\n' "$out"
			return 0
		fi
		sleep 1
	done
	return 1
}

is_authoritative() {
	local out
	systemctl is-active --quiet named || return 1
	out=$(cd /tmp && dig @"$SERVER" +norecurse +tries=1 +time=2 labdomain.com SOA 2>/dev/null) || return 1
	printf '%s\n' "$out" | grep -Eq 'flags:[^;]* aa[ ;]' || return 1
	printf '%s\n' "$out" | grep -q 'status: NOERROR'
}

has_serial() {
	[ "$(q labdomain.com SOA | awk 'NR == 1 { print $3 }')" = "2026012501" ]
}

has_a() {
	q "$1" A | grep -qx "$2"
}

has_ns() {
	q labdomain.com NS | grep -qx 'ns1.labdomain.com.'
}

has_cname() {
	q www.labdomain.com CNAME | grep -qx 'web.labdomain.com.'
}

has_mx() {
	q labdomain.com MX | grep -qx '10 mail.labdomain.com.'
}

grade_begin dns-02
criterion "Package bind is installed" rpm -q bind
criterion "Package bind-utils is installed" rpm -q bind-utils
criterion "Service named is running" systemctl is-active --quiet named
criterion "named is authoritative for labdomain.com" is_authoritative
criterion "SOA serial of labdomain.com is 2026012501" has_serial
criterion "NS record of labdomain.com is ns1.labdomain.com" has_ns
criterion "ns1.labdomain.com has address 192.168.1.5" has_a ns1.labdomain.com 192.168.1.5
criterion "web.labdomain.com has address 192.168.1.10" has_a web.labdomain.com 192.168.1.10
criterion "mail.labdomain.com has address 192.168.1.20" has_a mail.labdomain.com 192.168.1.20
criterion "www.labdomain.com is a CNAME for web.labdomain.com" has_cname
criterion "MX of labdomain.com is mail.labdomain.com, priority 10" has_mx
grade_end
