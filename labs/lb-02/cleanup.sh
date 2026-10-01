#!/bin/bash
# lb-02 cleanup: puts every node back into the state that the first
# setup.sh run recorded. nginx and httpd are removed where setup.sh found
# them missing; where they were already installed, their config files,
# the web pages, boot state and running state are restored. The firewall
# rules and the SELinux booleans of the solution go back to their
# recorded values.
# No "set -u": load-config.sh reads variables that may be unset.

source /opt/linux-labs/lib/load-config.sh
load_lab_config

# Nothing was started without multi-node support
[ "$NODES_ENABLED" = "true" ] || exit 0
[ "$NODE_COUNT" -ge 3 ] 2>/dev/null || exit 0

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/node.sh" <<'REMOTE'
pre=/var/tmp/lb-02.pre
bak=/var/tmp/lb-02.bak

# setup.sh never ran on this node: nothing to undo
[ -f "$pre" ] || exit 0

had() {
	grep -qx "$1" "$pre"
}

# rmunowned <dir>: remove a directory that no installed package owns
rmunowned() {
	[ -d "$1" ] || return 0
	rpm -qf "$1" >/dev/null 2>&1 || rm -rf "$1"
}

systemctl disable --now nginx httpd </dev/null >/dev/null 2>&1
rm -f /var/www/html/index.html /var/www/html/health /etc/nginx/conf.d/lb.conf \
	/etc/nginx/nginx.conf.rpmsave /etc/httpd/conf/httpd.conf.rpmsave \
	/var/log/nginx/lb_access.log /var/log/nginx/lb_error.log

if ! had nginx-installed; then
	rpm -q nginx >/dev/null 2>&1 && dnf -y remove nginx </dev/null >/dev/null 2>&1
	rm -f /etc/nginx/nginx.conf.rpmsave
	rmunowned /etc/nginx
	rmunowned /var/log/nginx
	rmunowned /var/lib/nginx
	rmunowned /usr/share/nginx
fi
if ! had httpd-installed; then
	rpm -q httpd >/dev/null 2>&1 && dnf -y remove httpd </dev/null >/dev/null 2>&1
	rm -f /etc/httpd/conf/httpd.conf.rpmsave
	rmunowned /etc/httpd
	rmunowned /var/log/httpd
	rmunowned /var/www
fi

for f in /etc/httpd/conf/httpd.conf /var/www/html/index.html /var/www/html/health /etc/nginx/nginx.conf; do
	b="$bak/$(basename "$f")"
	if [ -f "$b" ] && [ -d "$(dirname "$f")" ]; then
		cp -a "$b" "$f" && restorecon "$f" 2>/dev/null
	fi
done

for p in httpd nginx; do
	had "$p-installed" || continue
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
	run_on_node "$ip" "sudo -n bash -s" < "$tmp/node.sh" > /dev/null 2>&1 || {
		echo "Cleanup of node $n ($ip) failed" >&2
		rc=1
	}
done
exit "$rc"
