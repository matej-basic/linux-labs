#!/bin/bash
# lb-02 cleanup: undo setup and the solution on Nodes 1 to 3.
source /opt/linux-labs/lib/load-config.sh
set -u

# Nothing to undo when multi-node labs are not configured.
[ "$NODES_ENABLED" = true ] || exit 0

# Runs on every node: removes nginx and httpd with their lab configuration,
# the firewall openings and the SELinux booleans the solution created.
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

rc=0
for n in 1 2 3; do
	[ "$n" -le "$NODE_COUNT" ] || break
	ip=$(get_node_ip "$n")
	if ! reset_script | run_on_node "$ip" "bash -s" >/dev/null 2>&1; then
		echo "lb-02: could not clean up Node $n ($ip)." >&2
		rc=1
	fi
done
exit "$rc"
