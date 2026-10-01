#!/bin/bash
# lb-01 setup: puts the three nodes into the clean starting state (Apache
# and HAProxy stopped and disabled, no index page, no HAProxy config, no
# lab firewall rules, haproxy_connect_any off). Packages that were already
# installed before the lab stay installed; the first run records the state
# of every node so that cleanup.sh can put it back. Prints nothing on
# success.
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

for n in 1 2 3; do
	ip=$(get_node_ip "$n")
	if ! test_node_connectivity "$ip" >/dev/null; then
		echo "Cannot reach node $n ($ip) over SSH as $SSH_USER" >&2
		exit 1
	fi
done

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Remote reset, run as root on every node through "bash -s", so every
# command that could read stdin gets /dev/null instead of the script.
cat > "$tmp/node.sh" <<'REMOTE'
pre=/var/tmp/lb-01.pre
bak=/var/tmp/lb-01.bak
files="/etc/httpd/conf/httpd.conf /var/www/html/index.html /etc/haproxy/haproxy.cfg"

# First run only: what the node looked like before the lab
if [ ! -f "$pre" ]; then
	rm -rf "$bak"
	mkdir -p "$bak" || exit 1
	{
		for p in httpd haproxy; do
			rpm -q "$p" >/dev/null 2>&1 && echo "$p-installed"
			systemctl is-enabled --quiet "$p" 2>/dev/null && echo "$p-enabled"
			systemctl is-active --quiet "$p" 2>/dev/null && echo "$p-active"
		done
		firewall-cmd --permanent --query-service=http </dev/null >/dev/null 2>&1 && echo fw-http
		firewall-cmd --permanent --query-port=80/tcp </dev/null >/dev/null 2>&1 && echo fw-80
		firewall-cmd --permanent --query-port=8080/tcp </dev/null >/dev/null 2>&1 && echo fw-8080
		getsebool haproxy_connect_any 2>/dev/null | grep -q -- "--> on" && echo bool-on
	} > "$pre.tmp"
	for f in $files; do
		[ -f "$f" ] && cp -a "$f" "$bak/$(basename "$f")"
	done
	mv "$pre.tmp" "$pre" || exit 1
fi

systemctl disable --now haproxy httpd </dev/null >/dev/null 2>&1
for p in haproxy httpd; do
	if rpm -q "$p" >/dev/null 2>&1 && ! grep -qx "$p-installed" "$pre"; then
		dnf -y remove "$p" </dev/null >/dev/null 2>&1 || exit 1
	fi
done
rm -f /var/www/html/index.html /etc/httpd/conf/httpd.conf.rpmsave /etc/haproxy/haproxy.cfg.rpmsave
for f in /etc/httpd/conf/httpd.conf /etc/haproxy/haproxy.cfg; do
	b="$bak/$(basename "$f")"
	if [ -f "$b" ]; then
		cp -a "$b" "$f" && restorecon "$f" 2>/dev/null
	fi
done

firewall-cmd --permanent --remove-service=http </dev/null >/dev/null 2>&1
firewall-cmd --permanent --remove-port=80/tcp </dev/null >/dev/null 2>&1
firewall-cmd --permanent --remove-port=8080/tcp </dev/null >/dev/null 2>&1
firewall-cmd --reload </dev/null >/dev/null 2>&1
if getsebool haproxy_connect_any 2>/dev/null | grep -q -- "--> on"; then
	setsebool -P haproxy_connect_any off </dev/null || exit 1
fi
exit 0
REMOTE

for n in 1 2 3; do
	ip=$(get_node_ip "$n")
	if ! run_on_node "$ip" "sudo -n bash -s" < "$tmp/node.sh" > "$tmp/out" 2>&1; then
		echo "Preparing node $n ($ip) failed:" >&2
		cat "$tmp/out" >&2
		exit 1
	fi
done
