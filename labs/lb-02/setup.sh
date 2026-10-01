#!/bin/bash
# lb-02 setup: put Nodes 1 to 3 into a clean starting state.
source /opt/linux-labs/lib/load-config.sh
set -eu

if [ "$NODES_ENABLED" != true ]; then
	echo "lb-02 needs multi-node labs: run 'sudo labctl configure interactive'." >&2
	exit 1
fi
if [ "$NODE_COUNT" -lt 3 ]; then
	echo "lb-02 needs at least 3 nodes (NODE_COUNT is $NODE_COUNT)." >&2
	exit 1
fi

# Runs on every node: removes nginx and httpd with their lab configuration,
# the firewall openings and the SELinux booleans a previous run left behind.
reset_script() {
	cat <<'REMOTE'
S=
[ "$(id -u)" -eq 0 ] || S="sudo -n"
for u in nginx httpd; do
	$S systemctl disable --now "$u" >/dev/null 2>&1
done
for p in nginx httpd; do
	rpm -q "$p" >/dev/null 2>&1 && $S dnf -y remove "$p" >/dev/null 2>&1
done
$S rm -f /etc/nginx/conf.d/lb.conf /etc/nginx/nginx.conf.rpmsave \
	/etc/httpd/conf/httpd.conf.rpmsave /var/log/nginx/lb_access.log \
	/var/log/nginx/lb_error.log /var/www/html/index.html /var/www/html/health
if $S systemctl is-active firewalld >/dev/null 2>&1; then
	$S firewall-cmd --permanent --remove-port=8080/tcp >/dev/null 2>&1
	$S firewall-cmd --permanent --remove-service=http >/dev/null 2>&1
	$S firewall-cmd --reload >/dev/null 2>&1
fi
for b in httpd_can_network_connect httpd_can_network_relay; do
	if getsebool "$b" 2>/dev/null | grep -q ' on$'; then
		$S setsebool -P "$b" 0
	fi
done
exit 0
REMOTE
}

for n in 1 2 3; do
	ip=$(get_node_ip "$n")
	if ! test_node_connectivity "$ip" >/dev/null 2>&1; then
		echo "lb-02: Node $n ($ip) is not reachable over SSH." >&2
		exit 1
	fi
done

for n in 1 2 3; do
	ip=$(get_node_ip "$n")
	if ! reset_script | run_on_node "$ip" "bash -s" >/dev/null 2>&1; then
		echo "lb-02: could not prepare Node $n ($ip)." >&2
		exit 1
	fi
done
