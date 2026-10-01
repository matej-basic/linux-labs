#!/bin/bash
# lb-03 grader
source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/grading.sh

STATE_FILE=/opt/linux-labs/state/lb-03

grade_begin lb-03
grade_require_state lb-03 "$STATE_FILE"
[ "$NODES_ENABLED" = true ] ||
	grade_abort "Multi-node labs are enabled in the configuration"
[ "$NODE_COUNT" -ge 3 ] 2>/dev/null ||
	grade_abort "At least 3 nodes are configured"

VIP=$(head -n 1 "$STATE_FILE")
N1=$(get_node_ip 1)
N2=$(get_node_ip 2)
N3=$(get_node_ip 3)

# Remote commands run as SSH_USER, with sudo unless that is root
SUDO=""
[ "${SSH_USER:-root}" = root ] || SUDO="sudo "

# on_node <ip> <command>: run a command on a node, true if it succeeds
on_node() {
	run_on_node "$1" "$2" </dev/null
}

# service_enabled_running <ip> <unit>
service_enabled_running() {
	on_node "$1" "systemctl is-active --quiet $2 && systemctl is-enabled --quiet $2"
}

# httpd_listens_8080 <ip>
httpd_listens_8080() {
	on_node "$1" "${SUDO}ss -H -tlnp 'sport = :8080' | grep -q httpd"
}

# Active (non-comment) lines of keepalived.conf on a node
kconf() {
	run_on_node "$1" "${SUDO}cat /etc/keepalived/keepalived.conf" </dev/null 2>/dev/null |
		grep -Ev '^[[:space:]]*[#!]'
}

# keepalived_has_vip <ip>
keepalived_has_vip() {
	kconf "$1" | grep -Fwq "$VIP"
}

# kvalue <ip> <keyword>: the first value of a keyword in keepalived.conf
kvalue() {
	kconf "$1" | awk -v k="$2" '$1 == k { print $2; exit }'
}

# auth_enabled <ip>: password authentication with a non-empty password
auth_enabled() {
	[ "$(kvalue "$1" auth_type)" = PASS ] && [ -n "$(kvalue "$1" auth_pass)" ]
}

auth_both() {
	auth_enabled "$N1" && auth_enabled "$N2"
}

# same_value <keyword>: the keyword has the same non-empty value on both
same_value() {
	local a b
	a=$(kvalue "$N1" "$1")
	b=$(kvalue "$N2" "$1")
	[ -n "$a" ] && [ "$a" = "$b" ]
}

priority_at_least_100() {
	local p
	p=$(kvalue "$N1" priority)
	[ "${p:-0}" -ge 100 ] 2>/dev/null
}

priority_node2_lower() {
	local p1 p2
	p1=$(kvalue "$N1" priority)
	p2=$(kvalue "$N2" priority)
	[ -n "$p1" ] && [ -n "$p2" ] && [ "$p2" -lt "$p1" ] 2>/dev/null
}

# holds_vip <ip>: the VIP is assigned to an interface of the node
holds_vip() {
	on_node "$1" "ip -o -4 addr show | awk -v v='$VIP/' 'index(\$4, v) == 1 { f = 1 } END { exit !f }'"
}

# Exactly one of nodes 1 and 2 holds the VIP. keepalived needs a few
# seconds after a start, so try for up to 10 seconds.
vip_on_exactly_one() {
	local c
	for _ in 1 2 3 4 5 6 7 8 9 10; do
		c=0
		holds_vip "$N1" && c=$((c + 1))
		holds_vip "$N2" && c=$((c + 1))
		[ "$c" -eq 1 ] && return 0
		sleep 1
	done
	return 1
}

# backend_page <from> <backend> <n>: <backend>:8080 answers with the
# page of node <n> when asked from node <from>
backend_page() {
	on_node "$1" "curl -s --max-time 4 http://$2:8080/ | grep -Fq 'Backend Server - Node $3'"
}

# backend_ok <backend> <n>: reachable from both load balancer nodes
backend_ok() {
	backend_page "$N1" "$1" "$2" && backend_page "$N2" "$1" "$2"
}

# balanced_via <target>: asked from node 3, <target> port 80 returns the
# pages of all three backends within 9 requests. HAProxy health checks
# need a few seconds after a start, so try for up to 10 seconds.
balanced_via() {
	for _ in 1 2 3 4 5 6 7 8 9 10; do
		on_node "$N3" "
			out=\$(for r in 1 2 3 4 5 6 7 8 9; do
				curl -s --max-time 3 http://$1/ || true
			done)
			for n in 1 2 3; do
				echo \"\$out\" | grep -Fq \"Backend Server - Node \$n\" || exit 1
			done" && return 0
		sleep 1
	done
	return 1
}

for ip in "$N1" "$N2"; do
	criterion "HAProxy is enabled and running on $ip" service_enabled_running "$ip" haproxy
done
for ip in "$N1" "$N2"; do
	criterion "keepalived is enabled and running on $ip" service_enabled_running "$ip" keepalived
done
for ip in "$N1" "$N2" "$N3"; do
	criterion "httpd is enabled and running on $ip" service_enabled_running "$ip" httpd
done
for ip in "$N1" "$N2" "$N3"; do
	criterion "httpd listens on port 8080 on $ip" httpd_listens_8080 "$ip"
done
criterion "Backend $N1:8080 serves the page of node 1" backend_ok "$N1" 1
criterion "Backend $N2:8080 serves the page of node 2" backend_ok "$N2" 2
criterion "Backend $N3:8080 serves the page of node 3" backend_ok "$N3" 3
criterion "HAProxy on $N1 balances over all three backends" balanced_via "$N1"
criterion "HAProxy on $N2 balances over all three backends" balanced_via "$N2"
criterion "keepalived on $N1 lists the VIP $VIP" keepalived_has_vip "$N1"
criterion "keepalived on $N2 lists the VIP $VIP" keepalived_has_vip "$N2"
criterion "VRRP password authentication is enabled on both nodes" auth_both
criterion "Both nodes use the same VRRP password" same_value auth_pass
criterion "Both nodes use the same virtual router ID" same_value virtual_router_id
criterion "Node 1 has a VRRP priority of at least 100" priority_at_least_100
criterion "Node 2 has a lower VRRP priority than node 1" priority_node2_lower
criterion "Exactly one of nodes 1 and 2 holds the VIP $VIP" vip_on_exactly_one
criterion "The VIP $VIP balances over all three backends" balanced_via "$VIP"
grade_end
