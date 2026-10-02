#!/bin/bash
# lb-03 setup: puts nodes 1 to 3 into the clean starting state (httpd,
# haproxy and keepalived stopped, disabled and removed, so the student
# installs them; no index page, no lab firewall rules, haproxy_connect_any
# off) and records the VIP in the state file. The first run records each
# node's package set (lib/packages.sh) and the service, firewall, SELinux
# and configuration state, so that cleanup.sh can put it back. Prints
# nothing on success.
#
# The VIP is the address of node 1 with the last octet replaced by 100.
# The grader reads it from the state file.
# No "set -u": load-config.sh reads variables that may be unset.
set -e

STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/lb-03"

die() {
	echo "lb-03: $*" >&2
	exit 1
}

[ -r /opt/linux-labs/lib/load-config.sh ] || die "load-config.sh not found"
# shellcheck source=/dev/null
source /opt/linux-labs/lib/load-config.sh
# shellcheck source=/dev/null
source /opt/linux-labs/lib/packages.sh
load_lab_config

[ "$NODES_ENABLED" = true ] ||
	die "this lab needs multi-node labs enabled (run: sudo labctl configure interactive)"
[ "$NODE_COUNT" -ge 3 ] 2>/dev/null ||
	die "this lab needs 3 nodes, NODE_COUNT is $NODE_COUNT (run: sudo labctl configure set NODE_COUNT 3)"

for n in 1 2 3; do
	ip=$(get_node_ip "$n")
	[ -n "$ip" ] || die "no IP address configured for node $n"
	test_node_connectivity "$ip" </dev/null >/dev/null 2>&1 ||
		die "cannot reach node $n ($ip) over SSH as $SSH_USER"
done

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Remote reset, run as root on every node through "bash -s", so every
# command that could read stdin gets /dev/null instead of the script.
cat >"$tmp/node.sh" <<'REMOTE'
pre=/var/tmp/lb-03.pre
bak=/var/tmp/lb-03.bak
files="/etc/httpd/conf/httpd.conf /var/www/html/index.html /etc/haproxy/haproxy.cfg /etc/keepalived/keepalived.conf"
dirs="/etc/httpd /var/log/httpd /var/www /etc/haproxy /var/lib/haproxy /etc/keepalived"

# First run only: services, firewall, SELinux and configuration files as
# they were before the lab (the package set is in the package snapshot)
if [ ! -f "$pre" ]; then
	rm -rf "$bak"
	mkdir -p "$bak" || exit 1
	{
		for p in httpd haproxy keepalived; do
			systemctl is-enabled --quiet "$p" 2>/dev/null && echo "$p-enabled"
			systemctl is-active --quiet "$p" 2>/dev/null && echo "$p-active"
		done
		firewall-cmd --permanent --query-service=http </dev/null >/dev/null 2>&1 && echo fw-http
		firewall-cmd --permanent --query-port=8080/tcp </dev/null >/dev/null 2>&1 && echo fw-8080
		firewall-cmd --permanent --query-protocol=vrrp </dev/null >/dev/null 2>&1 && echo fw-vrrp
		getsebool haproxy_connect_any 2>/dev/null | grep -q -- "--> on" && echo bool-on
	} >"$pre.tmp"
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

# The student installs the three packages; cleanup.sh puts back the
# ones that were installed before the lab
systemctl disable --now keepalived haproxy httpd </dev/null >/dev/null 2>&1
for p in keepalived haproxy httpd; do
	if rpm -q "$p" >/dev/null 2>&1; then
		dnf -y remove "$p" </dev/null >/dev/null 2>&1 || exit 1
	fi
done
rm -f /var/www/html/index.html /etc/httpd/conf/httpd.conf.rpmsave \
	/etc/haproxy/haproxy.cfg.rpmsave /etc/keepalived/keepalived.conf.rpmsave

firewall-cmd --permanent --remove-service=http </dev/null >/dev/null 2>&1
firewall-cmd --permanent --remove-port=8080/tcp </dev/null >/dev/null 2>&1
firewall-cmd --permanent --remove-protocol=vrrp </dev/null >/dev/null 2>&1
firewall-cmd --reload </dev/null >/dev/null 2>&1
if getsebool haproxy_connect_any 2>/dev/null | grep -q -- "--> on"; then
	setsebool -P haproxy_connect_any off </dev/null || exit 1
fi
exit 0
REMOTE

for n in 1 2 3; do
	ip=$(get_node_ip "$n")
	if ! pkg_snapshot_node "$ip" lb-03 >"$tmp/out" 2>&1; then
		echo "lb-03: recording the packages of node $n ($ip) failed:" >&2
		cat "$tmp/out" >&2
		exit 1
	fi
	if ! run_on_node "$ip" "sudo -n bash -s" <"$tmp/node.sh" >"$tmp/out" 2>&1; then
		echo "lb-03: preparing node $n ($ip) failed:" >&2
		cat "$tmp/out" >&2
		exit 1
	fi
done

NODE1_IP=$(get_node_ip 1)
VIP="${NODE1_IP%.*}.100"

# The VIP must be free: nothing may answer on it after the reset
if command -v ping >/dev/null 2>&1 && ping -c 1 -W 1 "$VIP" >/dev/null 2>&1; then
	die "the VIP $VIP is already in use by another host"
fi

mkdir -p "$STATE_DIR"
echo "$VIP" >"$STATE_FILE"
chmod 644 "$STATE_FILE"
