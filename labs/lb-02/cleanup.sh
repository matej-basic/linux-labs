#!/bin/bash
# lb-02 cleanup: puts every node back into the state that the first
# setup.sh run recorded. The package set goes back through
# lib/packages.sh (nginx and httpd are removed where they were missing
# and installed again where setup.sh removed them). Where they were
# installed before, their config files, the web pages, boot state and
# running state are restored. The firewall rules and the SELinux
# booleans of the solution go back to their recorded values.
# No "set -u": load-config.sh reads variables that may be unset.

source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/packages.sh
load_lab_config

# Nothing was started without multi-node support
[ "$NODES_ENABLED" = "true" ] || exit 0
[ "$NODE_COUNT" -ge 3 ] 2>/dev/null || exit 0

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Before the package restore: stop the services, remove the lab files
cat > "$tmp/stop.sh" <<'REMOTE'
systemctl disable --now nginx httpd </dev/null >/dev/null 2>&1
rm -f /var/www/html/index.html /var/www/html/health /etc/nginx/conf.d/lb.conf \
	/etc/nginx/nginx.conf.rpmsave /etc/httpd/conf/httpd.conf.rpmsave \
	/var/log/nginx/lb_access.log /var/log/nginx/lb_error.log
exit 0
REMOTE

# After the package restore: configuration, services, firewall, SELinux
cat > "$tmp/node.sh" <<'REMOTE'
pre=/var/tmp/lb-02.pre
bak=/var/tmp/lb-02.bak

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

rm -f /etc/nginx/nginx.conf.rpmsave /etc/httpd/conf/httpd.conf.rpmsave
if ! rpm -q nginx >/dev/null 2>&1; then
	undir /etc/nginx
	undir /var/log/nginx
	undir /var/lib/nginx
	undir /usr/share/nginx
fi
if ! rpm -q httpd >/dev/null 2>&1; then
	undir /etc/httpd
	undir /var/log/httpd
	undir /var/www
fi

for f in /etc/httpd/conf/httpd.conf /var/www/html/index.html /var/www/html/health /etc/nginx/nginx.conf; do
	b="$bak/$(basename "$f")"
	if [ -f "$b" ] && [ -d "$(dirname "$f")" ]; then
		cp -a "$b" "$f" && restorecon "$f" 2>/dev/null
	fi
done

for p in httpd nginx; do
	rpm -q "$p" >/dev/null 2>&1 || continue
	had "$p-enabled" && systemctl enable "$p" </dev/null >/dev/null 2>&1
	had "$p-active" && systemctl start "$p" </dev/null >/dev/null 2>&1
done

fw() {
	firewall-cmd --permanent "$@" </dev/null >/dev/null 2>&1
}
if had fw-http; then fw --add-service=http; else fw --remove-service=http; fi
if had fw-8080; then fw --add-port=8080/tcp; else fw --remove-port=8080/tcp; fi
firewall-cmd --reload </dev/null >/dev/null 2>&1

for b in httpd_can_network_connect httpd_can_network_relay; do
	want=off
	had "$b-on" && want=on
	if ! getsebool "$b" 2>/dev/null | grep -q -- "--> $want"; then
		setsebool -P "$b" "$want" </dev/null
	fi
done

rm -rf "$pre" "$bak"
exit 0
REMOTE

rc=0
for n in 1 2 3; do
	ip=$(get_node_ip "$n")
	if ! run_on_node "$ip" "sudo -n bash -s" < "$tmp/stop.sh" > /dev/null 2>&1; then
		echo "Cleanup of node $n ($ip) failed" >&2
		rc=1
		continue
	fi
	pkg_restore_node "$ip" lb-02 2>"$tmp/err" || {
		echo "Restoring the packages of node $n ($ip) failed:" >&2
		grep -v "^Warning: Permanently added" "$tmp/err" >&2
		# Keep the records of this node for the next reset
		rc=1
		continue
	}
	run_on_node "$ip" "sudo -n bash -s" < "$tmp/node.sh" > /dev/null 2>&1 || {
		echo "Cleanup of node $n ($ip) failed" >&2
		rc=1
	}
done
exit "$rc"
