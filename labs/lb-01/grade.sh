#!/bin/bash
# lb-01 grader
source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/grading.sh
load_lab_config

grade_begin lb-01

[ "$NODES_ENABLED" = "true" ] || grade_abort "Multi-node labs are enabled in the configuration"
[ "$NODE_COUNT" -ge 3 ] 2>/dev/null || grade_abort "The configuration defines at least 3 nodes"

NODE1_IP=$(get_node_ip 1)
NODE2_IP=$(get_node_ip 2)
NODE3_IP=$(get_node_ip 3)
CFG=/etc/haproxy/haproxy.cfg

for ip in "$NODE1_IP" "$NODE2_IP" "$NODE3_IP"; do
	test_node_connectivity "$ip" >/dev/null 2>&1 || grade_abort "All three nodes are reachable over SSH"
done

# service_ok <ip> <unit>: unit is enabled and active
service_ok() {
	run_on_node "$1" "sudo -n systemctl is-enabled $2 && sudo -n systemctl is-active $2"
}

# listens <ip> <port> <process>: the process owns a listening TCP socket
listens() {
	run_on_node "$1" "sudo -n ss -tlnp 'sport = :$2'" | grep -q "\"$3\""
}

# backend_body <ip>: the page of a backend, fetched from node 1 as HAProxy
# would fetch it. Fails unless the answer is HTTP 200 with a body.
backend_body() {
	local body
	body=$(run_on_node "$NODE1_IP" "curl -fs --max-time 5 http://$1:8080/") || return 1
	[ -n "$body" ] || return 1
	printf '%s' "$body"
}

serves_page() {
	backend_body "$1" >/dev/null
}

pages_differ() {
	local b1 b2 b3
	b1=$(backend_body "$NODE1_IP") || return 1
	b2=$(backend_body "$NODE2_IP") || return 1
	b3=$(backend_body "$NODE3_IP") || return 1
	[ "$b1" != "$b2" ] && [ "$b1" != "$b3" ] && [ "$b2" != "$b3" ]
}

# haproxy.cfg without comment lines
cfg_active() {
	run_on_node "$NODE1_IP" "sudo -n cat $CFG" | grep -v '^[[:space:]]*#'
}

cfg_roundrobin() {
	cfg_active | grep -Eq '^[[:space:]]*balance[[:space:]]+roundrobin([[:space:]]|$)'
}

cfg_httpchk() {
	cfg_active | grep -Eq '^[[:space:]]*option[[:space:]]+httpchk([[:space:]]|$)'
}

cfg_backends() {
	local cfg ip re
	cfg=$(cfg_active) || return 1
	for ip in "$NODE1_IP" "$NODE2_IP" "$NODE3_IP"; do
		re="${ip//./\\.}"
		printf '%s\n' "$cfg" | grep -Eq "^[[:space:]]*server[[:space:]]+[^[:space:]]+[[:space:]]+$re:8080([[:space:]]+[^#]*)?[[:space:]]check([[:space:]]|\$)" || return 1
	done
}

# 12 requests from the workstation to node 1 port 80: every backend page
# comes back exactly 4 times (round-robin with equal weights)
lb_even() {
	local b1 b2 b3 r n=0 c1=0 c2=0 c3=0
	b1=$(backend_body "$NODE1_IP") || return 1
	b2=$(backend_body "$NODE2_IP") || return 1
	b3=$(backend_body "$NODE3_IP") || return 1
	# HAProxy needs a few seconds to mark the backends up
	for _ in $(seq 15); do
		curl -fs --max-time 5 "http://$NODE1_IP/" >/dev/null 2>&1 && break
		sleep 1
	done
	for _ in $(seq 12); do
		r=$(curl -fs --max-time 5 "http://$NODE1_IP/") || return 1
		case "$r" in
			"$b1") c1=$((c1 + 1)) ;;
			"$b2") c2=$((c2 + 1)) ;;
			"$b3") c3=$((c3 + 1)) ;;
		esac
		n=$((n + 1))
	done
	[ "$n" -eq 12 ] && [ "$c1" -eq 4 ] && [ "$c2" -eq 4 ] && [ "$c3" -eq 4 ]
}

# fw_permanent <ip> <service> <port/proto>: opened in the permanent config
# of the default zone, as a service or as a port
fw_permanent() {
	local out
	out=$(run_on_node "$1" "sudo -n firewall-cmd --permanent --list-all") || return 1
	if [ -n "$2" ] && printf '%s\n' "$out" | grep -Eq "^[[:space:]]*services:.*[[:space:]]$2([[:space:]]|\$)"; then
		return 0
	fi
	printf '%s\n' "$out" | grep -Eq "^[[:space:]]*ports:.*[[:space:]]$3([[:space:]]|\$)"
}

selinux_enforcing() {
	local ip
	for ip in "$NODE1_IP" "$NODE2_IP" "$NODE3_IP"; do
		[ "$(run_on_node "$ip" "getenforce")" = "Enforcing" ] || return 1
	done
}

criterion "httpd is enabled and running on node 1" service_ok "$NODE1_IP" httpd
criterion "httpd is enabled and running on node 2" service_ok "$NODE2_IP" httpd
criterion "httpd is enabled and running on node 3" service_ok "$NODE3_IP" httpd
criterion "httpd listens on port 8080 on node 1" listens "$NODE1_IP" 8080 httpd
criterion "httpd listens on port 8080 on node 2" listens "$NODE2_IP" 8080 httpd
criterion "httpd listens on port 8080 on node 3" listens "$NODE3_IP" 8080 httpd
criterion "Node 1 serves a page on port 8080" serves_page "$NODE1_IP"
criterion "Node 2 serves a page on port 8080" serves_page "$NODE2_IP"
criterion "Node 3 serves a page on port 8080" serves_page "$NODE3_IP"
criterion "The three backend pages differ from each other" pages_differ
criterion "haproxy is enabled and running on node 1" service_ok "$NODE1_IP" haproxy
criterion "haproxy listens on port 80 on node 1" listens "$NODE1_IP" 80 haproxy
criterion "haproxy.cfg uses balance roundrobin" cfg_roundrobin
criterion "haproxy.cfg lists all 3 backends on port 8080 with check" cfg_backends
criterion "haproxy.cfg enables HTTP health checks (option httpchk)" cfg_httpchk
criterion "Port 80/tcp is open permanently on node 1" fw_permanent "$NODE1_IP" http 80/tcp
criterion "Port 8080/tcp is open permanently on node 2" fw_permanent "$NODE2_IP" "" 8080/tcp
criterion "Port 8080/tcp is open permanently on node 3" fw_permanent "$NODE3_IP" "" 8080/tcp
criterion "SELinux is enforcing on all three nodes" selinux_enforcing
criterion "12 requests to node 1 port 80 reach each backend 4 times" lb_even
grade_end
