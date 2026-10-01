#!/bin/bash
# lb-02 grader
source /opt/linux-labs/lib/grading.sh
source /opt/linux-labs/lib/load-config.sh

grade_begin lb-02

[ "$NODES_ENABLED" = true ] || grade_abort "Multi-node labs are enabled in the configuration"
[ "$NODE_COUNT" -ge 3 ] || grade_abort "At least 3 nodes are configured"

N1=$(get_node_ip 1)
N2=$(get_node_ip 2)
N3=$(get_node_ip 3)

for ip in "$N1" "$N2" "$N3"; do
	test_node_connectivity "$ip" >/dev/null 2>&1 || grade_abort "Nodes 1 to 3 are reachable over SSH"
done

# Commands that need root on a node use $SU, which is sudo for a non-root
# SSH user.
SU=
[ "$SSH_USER" = root ] || SU="sudo -n"
rn() { run_on_node "$1" "$2"; }

# Output of the nginx configuration as nginx sees it, upstream blocks only.
upstream_conf() {
	rn "$N1" "$SU /usr/sbin/nginx -T 2>/dev/null | awk '/^[[:space:]]*upstream[[:space:]]/{u=1} u{print} u&&/}/{u=0}'"
}

# Effective nginx configuration with comment lines removed.
nginx_conf() {
	rn "$N1" "$SU /usr/sbin/nginx -T 2>/dev/null | grep -v '^[[:space:]]*#'"
}

service_up() {
	rn "$1" "systemctl is-active --quiet $2 && systemctl is-enabled --quiet $2"
}

listens() {
	rn "$1" "$SU ss -tlnp | awk '\$4 ~ /:$2\$/' | grep -q $3"
}

backend_serves() {
	local ip=$1 body
	body=$(rn "$N1" "curl -sf --max-time 5 http://$ip:8080$2")
	[[ $body == *"$3"* ]]
}

upstream_has_server() {
	local ip=${1//./\\.}
	upstream_conf | grep -Eq "^[[:space:]]*server[[:space:]]+$ip:8080([[:space:];]|$)"
}

upstream_servers_checked() {
	local ip line
	for ip in "$N2" "$N3"; do
		line=$(upstream_conf | grep -E "^[[:space:]]*server[[:space:]]+${ip//./\\.}:8080([[:space:];]|$)")
		echo "$line" | grep -Eq 'max_fails=[1-9][0-9]*' || return 1
		echo "$line" | grep -Eq 'fail_timeout=[0-9]+[smh]?([[:space:];]|$)' || return 1
	done
}

proxy_header() {
	nginx_conf | grep -Eiq "^[[:space:]]*proxy_set_header[[:space:]]+$1[[:space:]]"
}

upstream_keepalive() {
	upstream_conf | grep -Eq '^[[:space:]]*keepalive[[:space:]]+[1-9]'
}

nginx_has() {
	nginx_conf | grep -Eq "^[[:space:]]*$1[[:space:]]+$2[[:space:];]"
}

selinux_proxy() {
	[ "$(rn "$N1" getenforce)" = Enforcing ] || return 1
	rn "$N1" 'curl -sf --max-time 10 -o /dev/null http://127.0.0.1/'
}

proxy_balances() {
	local out i
	out=$(rn "$N1" 'for i in 1 2 3 4 5 6 7 8; do curl -s --max-time 10 http://127.0.0.1/; done')
	i=$(echo "$out" | grep -c 'Backend Server - Node 2')
	[ "$i" -ge 1 ] || return 1
	i=$(echo "$out" | grep -c 'Backend Server - Node 3')
	[ "$i" -ge 1 ]
}

failover_works() {
	local was out n
	was=$(rn "$N2" 'systemctl is-active httpd')
	rn "$N2" "$SU systemctl stop httpd" >/dev/null 2>&1
	out=$(rn "$N1" 'for i in 1 2 3 4 5 6; do curl -s --max-time 10 http://127.0.0.1/; done')
	[ "$was" = active ] && rn "$N2" "$SU systemctl start httpd" >/dev/null 2>&1
	n=$(echo "$out" | grep -c 'Backend Server - Node 3')
	[ "$n" -eq 6 ]
}

proxy_reachable_from_here() {
	curl -s --max-time 5 -o /dev/null "http://$N1/"
}

criterion "nginx is enabled and running on Node 1" service_up "$N1" nginx
criterion "nginx listens on port 80 on Node 1" listens "$N1" 80 nginx
criterion "httpd is enabled and running on Node 2" service_up "$N2" httpd
criterion "httpd is enabled and running on Node 3" service_up "$N3" httpd
criterion "httpd listens on port 8080 on Node 2" listens "$N2" 8080 httpd
criterion "httpd listens on port 8080 on Node 3" listens "$N3" 8080 httpd
criterion "Node 2 /health returns OK on port 8080 (from Node 1)" backend_serves "$N2" /health OK
criterion "Node 3 /health returns OK on port 8080 (from Node 1)" backend_serves "$N3" /health OK
criterion "Node 2 front page names Node 2 (from Node 1)" backend_serves "$N2" / "Backend Server - Node 2"
criterion "Node 3 front page names Node 3 (from Node 1)" backend_serves "$N3" / "Backend Server - Node 3"
criterion "Upstream group has Node 2 on port 8080" upstream_has_server "$N2"
criterion "Upstream group has Node 3 on port 8080" upstream_has_server "$N3"
criterion "Upstream servers set max_fails and fail_timeout" upstream_servers_checked
criterion "Upstream group sets keepalive" upstream_keepalive
criterion "Proxy speaks HTTP/1.1 to the backends" nginx_has proxy_http_version 1.1
criterion "Proxy sends the Host header to the backends" proxy_header Host
criterion "Proxy sends the X-Real-IP header to the backends" proxy_header X-Real-IP
criterion "Proxy sends the X-Forwarded-For header to the backends" proxy_header X-Forwarded-For
criterion "Node 1 accepts connections on port 80 from the workstation" proxy_reachable_from_here
criterion "Proxy works with SELinux enforcing on Node 1" selinux_proxy
criterion "Requests on port 80 are answered by both backends" proxy_balances
criterion "A stopped httpd on Node 2 causes no failed requests" failover_works
grade_end
