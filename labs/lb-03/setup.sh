#!/bin/bash
# lb-03 setup: puts nodes 1 to 3 into a clean starting state (no httpd,
# haproxy or keepalived, no lab firewall rules) and records the VIP in the
# state file. Prints nothing on success.
#
# The VIP is the address of node 1 with the last octet replaced by 100.
# The grader reads it from the state file.

STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/lb-03"

die() {
	echo "lb-03: $*" >&2
	exit 1
}

[ -r /opt/linux-labs/lib/load-config.sh ] || die "load-config.sh not found"
# shellcheck source=/dev/null
source /opt/linux-labs/lib/load-config.sh
load_lab_config

set -eu

[ "$NODES_ENABLED" = true ] ||
	die "this lab needs multi-node labs enabled (run: sudo labctl configure interactive)"
[ "$NODE_COUNT" -ge 3 ] 2>/dev/null ||
	die "this lab needs 3 nodes, NODE_COUNT is $NODE_COUNT (run: sudo labctl configure set NODE_COUNT 3)"

NODE1_IP=$(get_node_ip 1)

for n in 1 2 3; do
	ip=$(get_node_ip "$n")
	[ -n "$ip" ] || die "no IP address configured for node $n"
	test_node_connectivity "$ip" </dev/null >/dev/null 2>&1 ||
		die "cannot reach node $n ($ip) over SSH"
done

# Commands run on every node. SSH_USER is root by default; any other user
# needs passwordless sudo.
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

# The script travels base64 encoded, so quoting does not matter and the
# remote shell keeps its standard input free for the commands inside
payload=$(printf '%s\n' "$RESET_NODE" | base64 | tr -d '\n')
for n in 1 2 3; do
	ip=$(get_node_ip "$n")
	run_on_node "$ip" "${SUDO}sh -c \"\$(echo $payload | base64 -d)\"" \
		</dev/null >/dev/null 2>&1 || die "could not reset node $n ($ip)"
done

VIP="${NODE1_IP%.*}.100"

# The VIP must be free: nothing may answer on it after the reset
if command -v ping >/dev/null 2>&1 && ping -c 1 -W 1 "$VIP" >/dev/null 2>&1; then
	die "the VIP $VIP is already in use by another host"
fi

mkdir -p "$STATE_DIR"
echo "$VIP" >"$STATE_FILE"
chmod 644 "$STATE_FILE"
