#!/bin/bash
# lb-03 cleanup: puts every node back into the state that the first
# setup.sh run recorded. The package set goes back through
# lib/packages.sh (httpd, haproxy and keepalived are removed where they
# were missing and installed again where setup.sh removed them). Where
# they were installed before, their config files, the index page, boot
# state and running state are restored. The firewall rules and the
# SELinux boolean of the solution go back to their recorded values, and
# the VIP is released. Deletes the state file.
# No "set -u": load-config.sh reads variables that may be unset.

STATE_FILE=/opt/linux-labs/state/lb-03

if [ -r /opt/linux-labs/lib/load-config.sh ]; then
	# shellcheck source=/dev/null
	source /opt/linux-labs/lib/load-config.sh
	# shellcheck source=/dev/null
	source /opt/linux-labs/lib/packages.sh
	load_lab_config
fi

# Nothing was started on the nodes without multi-node support
if [ "${NODES_ENABLED:-false}" != true ] || ! [ "${NODE_COUNT:-0}" -ge 3 ] 2>/dev/null; then
	rm -f "$STATE_FILE"
	exit 0
fi

VIP=""
[ -r "$STATE_FILE" ] && VIP=$(head -n 1 "$STATE_FILE")

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Before the package restore: stop the services, release the VIP and
# remove the lab files
{
	echo "vip='$VIP'"
	cat <<'REMOTE'
systemctl disable --now keepalived haproxy httpd </dev/null >/dev/null 2>&1
rm -f /var/www/html/index.html /etc/httpd/conf/httpd.conf.rpmsave \
	/etc/haproxy/haproxy.cfg.rpmsave /etc/keepalived/keepalived.conf.rpmsave

# keepalived releases the VIP when it stops; remove a leftover address
if [ -n "$vip" ]; then
	ip -o -4 addr show | awk -v v="$vip/" 'index($4, v) == 1 { print $2, $4 }' |
		while read -r dev addr; do
			ip addr del "$addr" dev "$dev" </dev/null >/dev/null 2>&1
		done
fi
exit 0
REMOTE
} >"$tmp/stop.sh"

# After the package restore: directories, configuration, services,
# firewall, SELinux
cat >"$tmp/node.sh" <<'REMOTE'
pre=/var/tmp/lb-03.pre
bak=/var/tmp/lb-03.bak

# setup.sh never ran on this node: nothing to undo
[ -f "$pre" ] || exit 0

had() {
	grep -qx "$1" "$pre"
}

# undir <dir>: unless an installed package owns the directory, put it
# back as setup.sh found it: removed, or the copy setup.sh saved
undir() {
	rpm -qf "$1" >/dev/null 2>&1 && return 0
	rm -rf "$1"
	if [ -d "$bak/dirs$1" ]; then
		mkdir -p "$(dirname "$1")" && cp -a "$bak/dirs$1" "$1" && restorecon -R "$1" 2>/dev/null
	fi
	return 0
}

rm -f /etc/httpd/conf/httpd.conf.rpmsave /etc/haproxy/haproxy.cfg.rpmsave \
	/etc/keepalived/keepalived.conf.rpmsave
if ! rpm -q keepalived >/dev/null 2>&1; then
	undir /etc/keepalived
fi
if ! rpm -q haproxy >/dev/null 2>&1; then
	undir /etc/haproxy
	undir /var/lib/haproxy
fi
if ! rpm -q httpd >/dev/null 2>&1; then
	undir /etc/httpd
	undir /var/log/httpd
	undir /var/www
fi

for f in /etc/httpd/conf/httpd.conf /var/www/html/index.html /etc/haproxy/haproxy.cfg /etc/keepalived/keepalived.conf; do
	b="$bak/$(basename "$f")"
	if [ -f "$b" ] && [ -d "$(dirname "$f")" ]; then
		cp -a "$b" "$f" && restorecon "$f" 2>/dev/null
	fi
done

for p in httpd haproxy keepalived; do
	rpm -q "$p" >/dev/null 2>&1 || continue
	had "$p-enabled" && systemctl enable "$p" </dev/null >/dev/null 2>&1
	had "$p-active" && systemctl start "$p" </dev/null >/dev/null 2>&1
done

fw() {
	firewall-cmd --permanent "$@" </dev/null >/dev/null 2>&1
}
if had fw-http; then fw --add-service=http; else fw --remove-service=http; fi
if had fw-8080; then fw --add-port=8080/tcp; else fw --remove-port=8080/tcp; fi
if had fw-vrrp; then fw --add-protocol=vrrp; else fw --remove-protocol=vrrp; fi
firewall-cmd --reload </dev/null >/dev/null 2>&1

want=off
had bool-on && want=on
if ! getsebool haproxy_connect_any 2>/dev/null | grep -q -- "--> $want"; then
	setsebool -P haproxy_connect_any "$want" </dev/null
fi

rm -rf "$pre" "$bak"
exit 0
REMOTE

rc=0
for n in 1 2 3; do
	ip=$(get_node_ip "$n")
	if ! run_on_node "$ip" "sudo -n bash -s" <"$tmp/stop.sh" >/dev/null 2>&1; then
		echo "lb-03: cleanup of node $n ($ip) failed" >&2
		rc=1
		continue
	fi
	pkg_restore_node "$ip" lb-03 2>"$tmp/err" || {
		echo "lb-03: restoring the packages of node $n ($ip) failed:" >&2
		grep -v "^Warning: Permanently added" "$tmp/err" >&2
		# Keep the records of this node for the next reset
		rc=1
		continue
	}
	run_on_node "$ip" "sudo -n bash -s" <"$tmp/node.sh" >/dev/null 2>&1 || {
		echo "lb-03: cleanup of node $n ($ip) failed" >&2
		rc=1
	}
done

rm -f "$STATE_FILE"
exit "$rc"
