#!/bin/bash
# lb-01 setup: puts the three nodes into the clean starting state (no
# HAProxy, no Apache, no lab firewall rules). Prints nothing on success.
# No "set -u": load-config.sh reads variables that may be unset.
set -e

source /opt/linux-labs/lib/load-config.sh
load_lab_config

if [ "$NODES_ENABLED" != "true" ]; then
	echo "lb-01 needs multi-node labs: run 'sudo labctl configure interactive' and enable them" >&2
	exit 1
fi
if [ "$NODE_COUNT" -lt 3 ] 2>/dev/null; then
	echo "lb-01 needs 3 nodes, NODE_COUNT is $NODE_COUNT: run 'sudo labctl configure set NODE_COUNT 3'" >&2
	exit 1
fi

# Remote reset, run on every node through SSH. It ends with "true" so a
# missing package or an inactive firewall is not an error.
RESET_CMD='
sudo systemctl disable --now haproxy httpd >/dev/null 2>&1
sudo dnf -y remove haproxy >/dev/null 2>&1
sudo dnf -y remove httpd >/dev/null 2>&1
sudo rm -f /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.rpmsave /etc/httpd/conf/httpd.conf.rpmsave /var/www/html/index.html
sudo firewall-cmd --permanent --remove-service=http >/dev/null 2>&1
sudo firewall-cmd --permanent --remove-port=80/tcp >/dev/null 2>&1
sudo firewall-cmd --permanent --remove-port=8080/tcp >/dev/null 2>&1
sudo firewall-cmd --reload >/dev/null 2>&1
if getsebool haproxy_connect_any 2>/dev/null | grep -q -- "--> on"; then
	sudo setsebool -P haproxy_connect_any off
fi
true'

for n in 1 2 3; do
	ip=$(get_node_ip "$n")
	if ! test_node_connectivity "$ip" >/dev/null; then
		echo "Cannot reach node $n ($ip) over SSH as $SSH_USER" >&2
		exit 1
	fi
done

for n in 1 2 3; do
	ip=$(get_node_ip "$n")
	run_on_node "$ip" "$RESET_CMD" </dev/null >/dev/null 2>&1 || {
		echo "Resetting node $n ($ip) failed" >&2
		exit 1
	}
done
