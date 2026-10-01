#!/bin/bash
# lb-01 cleanup: puts every node back into the state that the first
# setup.sh run recorded. HAProxy and Apache are removed where setup.sh
# found them missing; where they were already installed, their config
# files, index page, boot state and running state are restored. The
# firewall rules and the SELinux boolean of the solution go back to their
# recorded values.
# No "set -u": load-config.sh reads variables that may be unset.

source /opt/linux-labs/lib/load-config.sh
load_lab_config

rm -f /tmp/haproxy.cfg

# Nothing was started without multi-node support
[ "$NODES_ENABLED" = "true" ] || exit 0
[ "$NODE_COUNT" -ge 3 ] 2>/dev/null || exit 0

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/node.sh" <<'REMOTE'
pre=/var/tmp/lb-01.pre
bak=/var/tmp/lb-01.bak

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

systemctl disable --now haproxy httpd </dev/null >/dev/null 2>&1
rm -f /var/www/html/index.html /etc/httpd/conf/httpd.conf.rpmsave /etc/haproxy/haproxy.cfg.rpmsave

if ! had haproxy-installed; then
	rpm -q haproxy >/dev/null 2>&1 && dnf -y remove haproxy </dev/null >/dev/null 2>&1
	rm -f /etc/haproxy/haproxy.cfg.rpmsave
	rmunowned /etc/haproxy
	rmunowned /var/lib/haproxy
fi
if ! had httpd-installed; then
	rpm -q httpd >/dev/null 2>&1 && dnf -y remove httpd </dev/null >/dev/null 2>&1
	rm -f /etc/httpd/conf/httpd.conf.rpmsave
	rmunowned /etc/httpd
	rmunowned /var/log/httpd
	rmunowned /var/www
fi

for f in /etc/httpd/conf/httpd.conf /var/www/html/index.html /etc/haproxy/haproxy.cfg; do
	b="$bak/$(basename "$f")"
	if [ -f "$b" ] && [ -d "$(dirname "$f")" ]; then
		cp -a "$b" "$f" && restorecon "$f" 2>/dev/null
	fi
done

for p in httpd haproxy; do
	had "$p-installed" || continue
	had "$p-enabled" && systemctl enable "$p" </dev/null >/dev/null 2>&1
	had "$p-active" && systemctl start "$p" </dev/null >/dev/null 2>&1
done

fw() {
	firewall-cmd --permanent "$@" </dev/null >/dev/null 2>&1
}
if had fw-http; then fw --add-service=http; else fw --remove-service=http; fi
if had fw-80; then fw --add-port=80/tcp; else fw --remove-port=80/tcp; fi
if had fw-8080; then fw --add-port=8080/tcp; else fw --remove-port=8080/tcp; fi
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
	run_on_node "$ip" "sudo -n bash -s" < "$tmp/node.sh" > /dev/null 2>&1 || {
		echo "Cleanup of node $n ($ip) failed" >&2
		rc=1
	}
done
exit "$rc"
