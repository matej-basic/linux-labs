#!/bin/bash
# dns-04 grader. Queries both named instances from node 2 and node 1
# and checks the transfer, the refusal and NOTIFY by behaviour, so the
# keywords of BIND 9.11 (Rocky 8) and 9.16 (Rocky 9) both work.
# The NOTIFY check changes the zone on node 1: it raises the serial,
# sets the TXT record grade-check.lab.example and reloads the zone.
source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/grading.sh
load_lab_config

LAB=dns-04
STATE_FILE=/opt/linux-labs/state/$LAB
ZONE=lab.example

grade_begin dns-04
grade_require_state dns-04 "$STATE_FILE"

[ "$NODES_ENABLED" = "true" ] || grade_abort "Multi-node labs are enabled in the configuration"
[ "$NODE_COUNT" -ge 2 ] 2>/dev/null || grade_abort "The configuration defines at least 2 nodes"

N1=$(get_node_ip 1)
N2=$(get_node_ip 2)
for ip in "$N1" "$N2"; do
	test_node_connectivity "$ip" >/dev/null 2>&1 || grade_abort "Nodes 1 and 2 are reachable over SSH"
done

# Facts both nodes report the same way. $1 is the address of the node.
COMMON=$(cat <<'REMOTE'
me=$1

systemctl is-enabled --quiet named 2>/dev/null &&
	systemctl is-active --quiet named 2>/dev/null && echo named
command -v named-checkconf >/dev/null 2>&1 &&
	named-checkconf /etc/named.conf >/dev/null 2>&1 && echo checkconf
rpm -q bind bind-utils >/dev/null 2>&1 && echo packages

# fw_proto <proto> [--permanent]: the zone of the interface with the
# node address (or the default zone) allows 53/<proto>, as a port or
# through a service
fw_proto() {
	local p=$1 iface zone s
	shift
	iface=$(ip -o -4 addr show | awk -v a="$me" '{ split($4, x, "/"); if (x[1] == a) print $2 }')
	zone=
	[ -n "$iface" ] && zone=$(firewall-cmd "$@" --get-zone-of-interface="$iface" 2>/dev/null)
	[ -n "$zone" ] || zone=$(firewall-cmd --get-default-zone 2>/dev/null)
	firewall-cmd "$@" --zone="$zone" --query-port="53/$p" >/dev/null 2>&1 && return 0
	for s in $(firewall-cmd "$@" --zone="$zone" --list-services 2>/dev/null); do
		firewall-cmd "$@" --info-service="$s" 2>/dev/null |
			grep -E '^[[:space:]]+ports:' |
			grep -Eq "(:|[[:space:]])53/$p([[:space:]]|\$)" && return 0
	done
	return 1
}
fw_proto tcp && fw_proto udp && echo fw-runtime
fw_proto tcp --permanent && fw_proto udp --permanent && echo fw-permanent
REMOTE
)

# Node 1: the common facts, and a transfer to its own address refused
# while named does answer that address over TCP
NODE1=$(run_on_node "$N1" "sudo -n bash -s -- $N1 $ZONE" 2>/dev/null <<REMOTE
$COMMON
zone=\$2
if dig +tcp +norec +time=3 +tries=1 -b "\$me" "@\$me" "\$zone" SOA 2>/dev/null |
	grep -q '^;; ->>HEADER<<-'; then
	out=\$(dig +noall +answer +time=5 +tries=1 -b "\$me" "@\$me" "\$zone" AXFR 2>/dev/null)
	printf '%s\n' "\$out" | awk '\$4 == "SOA" { s = 1 } END { exit s }' && echo refused
fi
exit 0
REMOTE
)

# Node 2: the common facts and every query, all sent from node 2
NODE2=$(run_on_node "$N2" "sudo -n bash -s -- $N2 $ZONE $N1" 2>/dev/null <<REMOTE
$COMMON
zone=\$2 n1=\$3

# aa <server>: the server answers the SOA query authoritatively
aa() {
	dig +noall +comments +norec +time=3 +tries=2 "@\$1" "\$zone" SOA 2>/dev/null |
		grep -Eq '^;; flags:.* aa[ ;]'
}
serial() {
	dig +short +norec +time=3 +tries=2 "@\$1" "\$zone" SOA 2>/dev/null | awk 'NF >= 7 { print \$3; exit }'
}

command -v dig >/dev/null 2>&1 || exit 0
aa "\$n1" && echo aa1
aa "\$me" && echo aa2
s1=\$(serial "\$n1")
s2=\$(serial "\$me")
[ -n "\$s1" ] && [ "\$s1" = "\$s2" ] && echo same-serial

dig +noall +answer +time=5 +tries=1 "@\$n1" "\$zone" AXFR 2>/dev/null |
	awk '\$4 == "SOA" { s = 1 } END { exit !s }' && echo axfr

# A file in /var/named/slaves that holds the zone, in raw or text format
for f in /var/named/slaves/*; do
	[ -f "\$f" ] && [ -s "\$f" ] || continue
	if named-checkzone -f raw "\$zone" "\$f" >/dev/null 2>&1 ||
		named-checkzone -f text "\$zone" "\$f" >/dev/null 2>&1; then
		echo slave-file
		break
	fi
done
exit 0
REMOTE
)

# has <node output> <fact>
has() {
	printf '%s\n' "$1" | grep -qx "$2"
}

# The NOTIFY check, last because it changes the zone on node 1: the zone
# file gets the next serial and a fresh TXT record grade-check, named
# reloads the zone, and node 2 must serve the new serial within 15
# seconds.
notify_works() {
	local new
	has "$NODE1" named || return 1
	new=$(run_on_node "$N1" "sudo -n bash -s -- $ZONE" 2>/dev/null <<'REMOTE'
zone=$1
file=/var/named/lab.example.zone
[ -f "$file" ] || exit 1
tmp=$(mktemp) || exit 1
trap 'rm -f "$tmp" "$tmp.new"' EXIT
named-checkzone -D -o "$tmp" "$zone" "$file" >/dev/null 2>&1 || exit 1
awk -v z="$zone." -v t="$(date +%s)" '
	$4 == "SOA" && !done { $7 = $7 + 1; serial = $7; done = 1 }
	$1 == "grade-check." z && $4 == "TXT" { next }
	{ print }
	END {
		print "grade-check." z " 300 IN TXT \"" t "\""
		print serial > "/dev/stderr"
	}' "$tmp" > "$tmp.new" 2> "$tmp.serial" || exit 1
named-checkzone -q "$zone" "$tmp.new" || exit 1
cat "$tmp.new" > "$file" || exit 1
rndc reload "$zone" >/dev/null 2>&1 || exit 1
cat "$tmp.serial"
rm -f "$tmp.serial"
REMOTE
)
	[ -n "$new" ] || return 1
	run_on_node "$N2" "bash -s -- $ZONE $N2 $new" >/dev/null 2>&1 <<'REMOTE'
zone=$1 me=$2 want=$3
for _ in $(seq 1 15); do
	s=$(dig +short +norec +time=1 +tries=1 "@$me" "$zone" SOA 2>/dev/null | awk 'NF >= 7 { print $3; exit }')
	[ "$s" = "$want" ] && exit 0
	sleep 1
done
exit 1
REMOTE
}

criterion "named is enabled and running on node 1" has "$NODE1" named
criterion "named-checkconf reports no errors on node 1" has "$NODE1" checkconf
criterion "The node 1 runtime firewall allows DNS on 53/tcp, 53/udp" has "$NODE1" fw-runtime
criterion "The node 1 permanent firewall allows DNS on 53/tcp, 53/udp" has "$NODE1" fw-permanent
criterion "Node 1 answers node 2 authoritatively for $ZONE" has "$NODE2" aa1
criterion "Node 1 allows node 2 to transfer $ZONE" has "$NODE2" axfr
criterion "Node 1 refuses a transfer of $ZONE to $N1" has "$NODE1" refused
criterion "Packages bind and bind-utils are installed on node 2" has "$NODE2" packages
criterion "named is enabled and running on node 2" has "$NODE2" named
criterion "named-checkconf reports no errors on node 2" has "$NODE2" checkconf
criterion "The node 2 runtime firewall allows DNS on 53/tcp, 53/udp" has "$NODE2" fw-runtime
criterion "The node 2 permanent firewall allows DNS on 53/tcp, 53/udp" has "$NODE2" fw-permanent
criterion "Node 2 answers authoritatively for $ZONE" has "$NODE2" aa2
criterion "Node 2 serves the same SOA serial as node 1" has "$NODE2" same-serial
criterion "Node 2 keeps the zone in a file in /var/named/slaves" has "$NODE2" slave-file
criterion "Node 2 has a change of the zone on node 1 within 15 seconds" notify_works
grade_end
