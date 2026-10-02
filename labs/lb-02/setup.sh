#!/bin/bash
# lb-02 setup: puts the three nodes into the clean starting state (nginx
# and httpd stopped and disabled, no index or health page, no proxy
# config, no lab firewall rules, the httpd network booleans off) and
# removes nginx and httpd, so the student installs them. The first run
# records each node's package set (lib/packages.sh) and the service,
# firewall, SELinux and configuration state, so that cleanup.sh can put
# it back. Prints nothing on success.
# No "set -u": load-config.sh reads variables that may be unset.
set -e

source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/packages.sh
load_lab_config

if [ "$NODES_ENABLED" != "true" ]; then
	echo "lb-02 needs multi-node labs: run 'sudo labctl configure interactive' and enable them" >&2
	exit 1
fi
if [ "$NODE_COUNT" -lt 3 ] 2>/dev/null; then
	echo "lb-02 needs 3 nodes, NODE_COUNT is $NODE_COUNT: run 'sudo labctl configure set NODE_COUNT 3'" >&2
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
pre=/var/tmp/lb-02.pre
bak=/var/tmp/lb-02.bak
files="/etc/httpd/conf/httpd.conf /var/www/html/index.html /var/www/html/health /etc/nginx/nginx.conf"
dirs="/etc/httpd /var/log/httpd /var/www /etc/nginx /var/log/nginx /var/lib/nginx /usr/share/nginx"
bools="httpd_can_network_connect httpd_can_network_relay"

# First run only: services, firewall, SELinux and configuration files as
# they were before the lab (the package set is in the package snapshot)
if [ ! -f "$pre" ]; then
	rm -rf "$bak"
	mkdir -p "$bak" || exit 1
	{
		for p in httpd nginx; do
			systemctl is-enabled --quiet "$p" 2>/dev/null && echo "$p-enabled"
			systemctl is-active --quiet "$p" 2>/dev/null && echo "$p-active"
		done
		firewall-cmd --permanent --query-service=http </dev/null >/dev/null 2>&1 && echo fw-http
		firewall-cmd --permanent --query-port=8080/tcp </dev/null >/dev/null 2>&1 && echo fw-8080
		for b in $bools; do
			getsebool "$b" 2>/dev/null | grep -q -- "--> on" && echo "$b-on"
		done
	} > "$pre.tmp"
	for f in $files; do
		[ -f "$f" ] && cp -a "$f" "$bak/$(basename "$f")"
	done
	# Directories that no package owns (left over from an earlier
	# install): cleanup.sh puts them back as they are now
	for d in $dirs; do
		if [ -d "$d" ] && ! rpm -qf "$d" >/dev/null 2>&1; then
			mkdir -p "$bak/dirs$(dirname "$d")" && cp -a "$d" "$bak/dirs$d" || exit 1
		fi
	done
	mv "$pre.tmp" "$pre" || exit 1
fi

# The student installs nginx and httpd; cleanup.sh puts back the ones
# that were installed before the lab
systemctl disable --now nginx httpd </dev/null >/dev/null 2>&1
for p in nginx httpd; do
	if rpm -q "$p" >/dev/null 2>&1; then
		dnf -y remove "$p" </dev/null >/dev/null 2>&1 || exit 1
	fi
done
rm -f /var/www/html/index.html /var/www/html/health /etc/nginx/conf.d/lb.conf \
	/etc/nginx/nginx.conf.rpmsave /etc/httpd/conf/httpd.conf.rpmsave \
	/var/log/nginx/lb_access.log /var/log/nginx/lb_error.log

firewall-cmd --permanent --remove-service=http </dev/null >/dev/null 2>&1
firewall-cmd --permanent --remove-port=8080/tcp </dev/null >/dev/null 2>&1
firewall-cmd --reload </dev/null >/dev/null 2>&1
for b in $bools; do
	if getsebool "$b" 2>/dev/null | grep -q -- "--> on"; then
		setsebool -P "$b" off </dev/null || exit 1
	fi
done
exit 0
REMOTE

for n in 1 2 3; do
	ip=$(get_node_ip "$n")
	if ! pkg_snapshot_node "$ip" lb-02 > "$tmp/out" 2>&1; then
		echo "Recording the packages of node $n ($ip) failed:" >&2
		cat "$tmp/out" >&2
		exit 1
	fi
	if ! run_on_node "$ip" "sudo -n bash -s" < "$tmp/node.sh" > "$tmp/out" 2>&1; then
		echo "Preparing node $n ($ip) failed:" >&2
		cat "$tmp/out" >&2
		exit 1
	fi
done
