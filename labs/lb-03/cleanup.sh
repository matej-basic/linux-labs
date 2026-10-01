#!/bin/bash
# lb-03 cleanup: removes httpd, haproxy and keepalived with their
# configuration from nodes 1 to 3, removes the lab firewall rules and the
# SELinux boolean the solution sets, and deletes the state file.
# Releases the VIP because keepalived is stopped first.

STATE_FILE=/opt/linux-labs/state/lb-03

if [ -r /opt/linux-labs/lib/load-config.sh ]; then
	# shellcheck source=/dev/null
	source /opt/linux-labs/lib/load-config.sh
	load_lab_config
fi

SUDO=""
[ "${SSH_USER:-root}" = root ] || SUDO="sudo "

read -r -d '' RESET_NODE <<'REMOTE' || true
for svc in keepalived haproxy httpd; do
    systemctl disable --now "$svc" >/dev/null 2>&1 || true
done
pkgs=""
for p in keepalived haproxy httpd; do
    rpm -q "$p" >/dev/null 2>&1 && pkgs="$pkgs $p"
done
[ -z "$pkgs" ] || dnf -y remove $pkgs >/dev/null 2>&1 || true
rm -f /etc/keepalived/keepalived.conf* /etc/haproxy/haproxy.cfg* \
    /etc/httpd/conf/httpd.conf.rpmsave /var/www/html/index.html
if systemctl is-active firewalld >/dev/null 2>&1; then
    firewall-cmd -q --permanent --remove-port=8080/tcp >/dev/null 2>&1 || true
    firewall-cmd -q --permanent --remove-service=http >/dev/null 2>&1 || true
    firewall-cmd -q --permanent --remove-protocol=vrrp >/dev/null 2>&1 || true
    firewall-cmd -q --reload >/dev/null 2>&1 || true
fi
if getsebool haproxy_connect_any 2>/dev/null | grep -q -- '--> on'; then
    setsebool -P haproxy_connect_any 0 >/dev/null 2>&1 || true
fi
exit 0
REMOTE

# Nodes are only touched when the lab was configured for them; a lab that
# never started has nothing to undo
if [ "${NODES_ENABLED:-false}" = true ] && [ "${NODE_COUNT:-0}" -ge 3 ] 2>/dev/null &&
	[ -r "$STATE_FILE" ]; then
	payload=$(printf '%s\n' "$RESET_NODE" | base64 | tr -d '\n')
	for n in 1 2 3; do
		ip=$(get_node_ip "$n")
		run_on_node "$ip" "${SUDO}sh -c \"\$(echo $payload | base64 -d)\"" \
			</dev/null >/dev/null 2>&1 ||
			echo "lb-03: could not clean node $n ($ip)" >&2
	done
fi

rm -f "$STATE_FILE"
exit 0
