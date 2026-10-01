#!/bin/bash
# lb-01 cleanup: removes HAProxy and Apache from the nodes together with
# their configuration, the test page, the firewall rules and the SELinux
# boolean that the solution sets. Same reset as setup.sh.
# No "set -u": load-config.sh reads variables that may be unset.

source /opt/linux-labs/lib/load-config.sh
load_lab_config

rm -f /tmp/haproxy.cfg

# Nothing was started without multi-node support
[ "$NODES_ENABLED" = "true" ] || exit 0
[ "$NODE_COUNT" -ge 3 ] 2>/dev/null || exit 0

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

rc=0
for n in 1 2 3; do
	ip=$(get_node_ip "$n")
	run_on_node "$ip" "$RESET_CMD" </dev/null >/dev/null 2>&1 || {
		echo "Cleanup of node $n ($ip) failed" >&2
		rc=1
	}
done
exit "$rc"
